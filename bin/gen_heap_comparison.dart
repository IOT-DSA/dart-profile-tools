import "dart:io";

import "package:dsa_profile_tools/heap_snapshot.dart";
import "package:dsa_profile_tools/utils.dart";

import "package:msgpack/msgpack.dart";

main(List<String> args) async {
  if (args.length != 2) {
    print("Usage: gen_heap_comparison <old_heap_snapshot> <new_heap_snapshot>");
    exit(1);
    return;
  }

  var outputFile = new File("heap_comparison.ppk");
  var fileOld = new File(args[0]);
  var fileNew = new File(args[1]);

  print("== Loading Old Heap Snapshot. ==");
  var oldSnapshot = await HeapSnapshot.load(fileOld);

  print("== Loading New Heap Snapshot. ==");
  var newSnapshot = await HeapSnapshot.load(fileNew);

  var minutes = oldSnapshot.timestamp.difference(newSnapshot.timestamp).abs().inSeconds / 60;
  print("== ${minutes.toStringAsFixed(2)} minutes between snapshots ==");

  var timestamp = new DateTime.now();

  var compare = oldSnapshot.compare(newSnapshot, autoCalculate: false);
  compare.calculate(progress: true);

  var output = [];

  print("== Generating Comparison. ==");

  for (Pair<SnapshotObject, SnapshotObject> pair in compare.findMemoryIncreases()) {
    var map = {
      "objectId": pair.left.objectId,
      "type": pair.left.type,
      "oldSize": pair.left.retainedSize,
      "newSize": pair.right.retainedSize,
      "increase": pair.right.retainedSize - pair.left.retainedSize
    };

    output.add(map);
  }

  var out = {
    "increases": output,
    "timestamp": timestamp.toString(),
    "minutes": minutes,
    "oldSnapshotTimestamp": oldSnapshot.timestamp.toString(),
    "newSnapshotTimestamp": newSnapshot.timestamp.toString()
  };

  var packer = new StatefulPacker();
  packer.pack(out);
  await outputFile.writeAsBytes(packer.done());

  print("== Comparison Generated. ==");
  exit(0);
}
