import "dart:io";

import "package:vm_service/service_io.dart";

main(List<String> args) async {
  if (args.length != 2) {
    print("Usage: get_open_sockets <observatory_url> <isolate_id>");
    exit(1);
    return;
  }
  var target = new WebSocketVMTarget(args[0]);
  var vm = new WebSocketVM(target);
  vm = await vm.load();
  Isolate i = await vm.getIsolate(args[1]);

  var result = await i.invokeRpcNoUpgrade("ext.dart.io.getOpenSockets", {});
  List data = result["data"];

  for (var e in data) {
    int id = e["id"];
    String name = e["name"];

    print("== ${id}: ${name} ==");

    var info = await i.invokeRpcNoUpgrade('ext.dart.io.getSocketByID', {
      'id': id
    });

    bool isListening = info["listening"];
    String socketType = info["socketType"];
    int port = info["port"];
    num lastRead = info["lastRead"];
    int totalRead = info["totalRead"];
    String remoteHost = info["remoteHost"];
    int remotePort = info["remotePort"];

    print("  Is Listening: ${isListening}");
    print("  Socket Type: ${socketType}");
    print("  Port: ${port}");
    print("  Last Read: ${lastRead}");
    print("  Total Read: ${totalRead}");
    print("  Remote Host: ${remoteHost}");
    print("  Remote Port: ${remotePort}");
  }

  exit(0);
}
