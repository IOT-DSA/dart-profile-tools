import "dart:io";

import "package:vm_service/service_io.dart";

main(List<String> args) async {
  if (args.length != 2) {
    print("Usage: gen_heap_snapshot <observatory_url> <isolate_id>");
    exit(1);
    return;
  }
  var target = new WebSocketVMTarget(args[0]);
  var vm = new WebSocketVM(target);
  vm = await vm.load();
  Isolate i = await vm.getIsolate(args[1]);

  await i.invokeRpc("_getAllocationProfile", {"gc": "full"});
  exit(0);
}
