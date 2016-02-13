import "dart:io";
import "dart:convert";

import "package:vm_service/service_io.dart";

main(List<String> args) async {
  if (args.length != 2) {
    print("Usage: type_instance_collector <observatory_url> <isolate_id>");
    exit(1);
    return;
  }

  var heapTimestamp = new DateTime.now();
  var outputFile = new File("type_instances.ppk");

  var target = new WebSocketVMTarget(args[0]);
  var vm = new WebSocketVM(target);
  vm = await vm.load();
  Isolate i = await vm.getIsolate(args[1]);

  var outpat = {};

  var profile = await i.invokeRpc("_getAllocationProfile", {"gc": "full"});

  for (ServiceMap map in profile["members"]) {
    Class cls = map["class"];
    if (cls == null) {
      continue;
    }

    await cls.load();

    if (cls.hasNoAllocations) {
      continue;
    }

    outpat[cls.name] = {
      "new": cls.newSpace.current.instances,
      "old": cls.oldSpace.current.instances,
      "total": cls.newSpace.current.instances + cls.oldSpace.current.instances
    };
  }

  var keys = outpat.keys.toList();
  keys.sort((a, b) {
    return outpat[b]["total"] - outpat[a]["total"];
  });

  var output = {};
  for (var key in keys) {
    output[key] = outpat[key];
  }

  var out = {
    "timestamp": heapTimestamp.toString(),
    "isolateId": i.id,
    "instances": output
  };

  await outputFile.writeAsString(const JsonEncoder.withIndent("  ").convert(out));

  print("== Success: Instances Generated. ==");
  exit(0);
}
