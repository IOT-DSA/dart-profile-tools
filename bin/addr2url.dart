import "dart:io";

import "package:vm_service/service_io.dart";

main(List<String> args) async {
  if (args.length != 3) {
    print("Usage: gc <observatory_url> <isolate_id> <object>");
    exit(1);
    return;
  }
  var target = new WebSocketVMTarget(args[0]);
  var vm = new WebSocketVM(target);
  vm = await vm.load();
  Isolate i = await vm.getIsolate(args[1]);
  var obj = await i.getObjectByAddress(args[2]);
  var uri = Uri.parse(args[0]);
  uri = uri.replace(
    scheme: "http",
    path: "/",
    fragment: "/inspect?isolateId=${Uri.encodeComponent(args[1])}&objectId=${Uri.encodeComponent(obj.id)}"
  );

  print("Url: ${uri}");

  exit(0);
}
