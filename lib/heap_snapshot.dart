library dsa.profile.heap_snapshot;

import "dart:async";
import "dart:io";

import "package:msgpack/msgpack.dart";

import "utils.dart";

class SnapshotObject {
  String type;
  String objectId;
  int shallowSize;
  int retainedSize;

  SnapshotObject();

  static SnapshotObject decode(Map input) {
    var object = new SnapshotObject();

    object
      ..type = input["type"]
      ..objectId = input["objectId"]
      ..shallowSize = input["shallowSize"]
      ..retainedSize = input["retainedSize"];

    return object;
  }

  static List<SnapshotObject> decodeAll(List<Map> inputs) {
    return inputs.map(decode).toList();
  }
}

class HeapSnapshot {
  List<SnapshotObject> objects;
  DateTime timestamp;
  String isolateId;
  TypeAnalysis typeAnalysis;

  HeapSnapshot();

  static Future<HeapSnapshot> load(File file) async {
    Map<String, dynamic> input = unpack(await file.readAsBytes());
    var snapshot = new HeapSnapshot();
    var objects = SnapshotObject.decodeAll(input["snapshot"]);

    objects.sort((a, b) => b.retainedSize - a.retainedSize);

    snapshot
      ..objects = objects
      ..timestamp = DateTime.parse(input["timestamp"])
      ..isolateId = input["isolateId"];
    return snapshot;
  }

  int get objectCount => objects.length;

  bool hasObject(String id) {
    return _getObjectIndex().contains(id);
  }

  Set<String> _objectIdIndex;

  Set<String> _getObjectIndex() {
    if (_objectIdIndex != null) {
      return _objectIdIndex;
    }

    return _objectIdIndex = objects
      .map((object) => object.objectId)
      .toSet();
  }

  void runTypeAnalysis() {
    List<String> types = objects.map((object) {
      return object.type;
    }).toList();
    List<Pair<String, int>> uses = [];

    Set<String> typeSet = types.toSet();
    for (String type in typeSet) {
      var count = types.where((e) => e == type).length;
      uses.add(new Pair<String, int>(type, count));
    }

    uses.sort((a, b) => b.right - a.right);

    typeAnalysis = new TypeAnalysis(
      typeSet,
      uses
    );
  }

  HeapComparison compare(HeapSnapshot other) {
    return new HeapComparison(this, other);
  }

  SnapshotObject getObject(String objectId) {
    return objects.firstWhere((object) => object.objectId == objectId);
  }
}

class HeapComparison extends Pair<HeapSnapshot, HeapSnapshot> {
  List<Pair<SnapshotObject, SnapshotObject>> sharedObjects;

  HeapComparison(HeapSnapshot left, HeapSnapshot right) : super(left, right) {
    _calculate();
  }

  void _calculate() {
    sharedObjects = <Pair<SnapshotObject, SnapshotObject>>[];

    Iterable<SnapshotObject> objects = right.objects
      .where((object) => left.hasObject(object.objectId));

    for (SnapshotObject last in objects) {
      SnapshotObject first = left.getObject(last.objectId);

      sharedObjects.add(new Pair<SnapshotObject, SnapshotObject>(first, last));
    }
  }

  Iterable<Pair<SnapshotObject, SnapshotObject>> findMemoryIncreases({
    bool shallow: false
  }) {
    return sharedObjects.where((pair) {
      if (shallow) {
        return (pair.right.shallowSize - pair.left.shallowSize) > 0;
      } else {
        return (pair.right.retainedSize - pair.left.retainedSize) > 0;
      }
    });
  }
}

class TypeAnalysis {
  final Set<String> typeSet;
  final List<Pair<String, int>> uses;

  TypeAnalysis(this.typeSet, this.uses);

  List<String> findMostUsedTypes(int count) {
    return uses.take(count).map((pair) => pair.left).toList();
  }

  int getTypeUsage(String type) {
    return uses.firstWhere((pair) => pair.left == type).right;
  }
}
