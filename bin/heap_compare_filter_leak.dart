import "dart:io";

import "package:dsa_profile_tools/heap_snapshot.dart";
import "package:msgpack/msgpack.dart";

main(List<String> args) async {
  if (args.length != 2) {
    print("Usage: heap_compare_filter_leak <heap_comparison_a> <heap_comparison_b>");
    exit(1);
    return;
  }

  var fileA = new File(args[0]);
  var compareA = await HeapComparison.load(fileA);

  var fileB = new File(args[0]);
  var compareB = await HeapComparison.load(fileB);

  var idsA = compareA.increases.map((increase) => increase.objectId).toSet();
  var idsB = compareB.increases.map((increase) => increase.objectId).toSet();
  var shared = idsA.union(idsB);

  var out = new File("heap_comparison_leaks.ppk");
  await out.writeAsBytes(pack({
    "increases": compareB.increases.where((increase) => shared.contains(increase.objectId)).map((increase) {
      return {
        "type": increase.type,
        "oldSize": increase.oldSize,
        "newSize": increase.newSize,
        "increase": increase.increase,
        "objectId": increase.objectId
      };
    }).toList()
  }));
}
