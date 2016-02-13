import "dart:io";

import "package:dsa_profile_tools/heap_snapshot.dart";

main(List<String> args) async {
  if (args.length != 1) {
    print("Usage: heap_comparison_simple_report <heap_comparison>");
    exit(1);
    return;
  }

  var file = new File(args[0]);
  var compare = await HeapComparison.load(file);

  print("== Heap Increases ==");
  for (HeapComparisonIncrease increase in compare.increases) {
    print("- ${increase.objectId}:");
    print("  Type: ${increase.type}");
    print("  Old Size: ${increase.oldSize} bytes");
    print("  New Size: ${increase.newSize} bytes");
    print("  Increase: ${increase.increase} bytes");
  }
}
