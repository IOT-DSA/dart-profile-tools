import "dart:io";

import "package:dsa_profile_tools/heap_snapshot.dart";

main(List<String> args) async {
  if (args.length != 1) {
    print("Usage: heap_stats <heap_snapshot>");
    exit(1);
    return;
  }

  var file = new File(args[0]);
  var snapshot = await HeapSnapshot.load(file);
  snapshot.runTypeAnalysis();

  var largestObject = snapshot.objects.first;
  print("Largest Object: ${largestObject.objectId}"
    " (${largestObject.type}) at ${largestObject.retainedSize}"
    " retained bytes.");

  print("${snapshot.typeAnalysis.typeSet.length} unique types.");
  print("Most Used Types:");
  for (String type in snapshot.typeAnalysis.findMostUsedTypes(8)) {
    print("- ${type} (${snapshot.typeAnalysis.getTypeUsage(type)} uses)");
  }
}
