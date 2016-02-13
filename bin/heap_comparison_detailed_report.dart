import "dart:io";

import "package:dsa_profile_tools/heap_snapshot.dart";

main(List<String> args) async {
  if (args.length != 1) {
    print("Usage: heap_comparison_detailed_report <heap_comparison>");
    exit(1);
    return;
  }

  var file = new File(args[0]);
  var compare = await HeapComparison.load(file);
  var out = new StringBuffer();

  var count = 0;
  out.writeln("# Heap Comparison");
  out.writeln();
  out.writeln("## Object Increases");
  for (HeapComparisonIncrease increase in compare.increases) {
    count++;

    out.writeln();
    out.writeln("### Rank ${count} - ${increase.objectId}");
    out.writeln();
    out.writeln("**Type**: `${increase.type}`<br/>");
    out.writeln("**Old Size**: ${increase.oldSize} bytes<br/>");
    out.writeln("**New Size**: ${increase.newSize} bytes<br/>");
    out.writeln("**Increase**: ${increase.increase} bytes<br/>");
  }

  var outputFile = new File("heap_compare_report.md");
  await outputFile.writeAsString(out.toString());
}
