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

  HeapComparisonBuilder compare(HeapSnapshot other, {bool autoCalculate: true}) {
    return new HeapComparisonBuilder(this, other, autoCalculate: autoCalculate);
  }

  SnapshotObject getObject(String objectId) {
    return objects.firstWhere((object) => object.objectId == objectId);
  }
}

class HeapComparison {
  List<HeapComparisonIncrease> increases;

  static Future<HeapComparison> load(File file) async {
    Map<String, dynamic> input = unpack(await file.readAsBytes());
    var comparison = new HeapComparison();
    comparison.increases = (input["increases"] as List<Map>).map((Map m) {
      var increase = new HeapComparisonIncrease();
      increase
        ..objectId = m["objectId"]
        ..oldSize = m["oldSize"]
        ..newSize = m["newSize"]
        ..increase = m["increase"]
        ..type = m["type"];

      return increase;
    }).toList();

    comparison.increases.sort((a, b) {
      return b.increase.compareTo(a.increase);
    });

    return comparison;
  }
}

class HeapComparisonIncrease {
  String type;
  String objectId;
  int oldSize;
  int newSize;
  int increase;
}

class HeapComparisonBuilder extends Pair<HeapSnapshot, HeapSnapshot> {
  List<Pair<SnapshotObject, SnapshotObject>> sharedObjects;

  HeapComparisonBuilder(HeapSnapshot left, HeapSnapshot right, {bool autoCalculate: true}) : super(left, right) {
    if (autoCalculate) {
      calculate();
    }
  }

  void calculate({bool progress: false}) {
    sharedObjects = <Pair<SnapshotObject, SnapshotObject>>[];

    Iterable<SnapshotObject> objects = right.objects
      .where((object) => left.hasObject(object.objectId));

    for (SnapshotObject last in objects) {
      SnapshotObject first = left.getObject(last.objectId);

      sharedObjects.add(new Pair<SnapshotObject, SnapshotObject>(first, last));

      if (progress && (sharedObjects.length % 20) == 0) {
        print("== Found ${sharedObjects.length} shared objects ==");
      }
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
