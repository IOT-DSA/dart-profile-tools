import "dart:io";

import "package:observe/observe.dart";
import "package:vm_service/service_io.dart";
import "package:vm_service/object_graph.dart";

import "package:msgpack/msgpack.dart";

main(List<String> args) async {
  if (args.length != 2) {
    print("Usage: gen_heap_snapshot <observatory_url> <isolate_id>");
    exit(1);
    return;
  }

  var heapTimestamp = new DateTime.now();
  var outputFile = new File("heap_snapshot.ppk");

  var target = new WebSocketVMTarget(args[0]);
  var vm = new WebSocketVM(target);
  vm = await vm.load();
  Isolate i = await vm.getIsolate(args[1]);

  await i.getClassRefs();

  var output = [];

  {
    HeapSnapshot snapshot = await i.fetchHeapSnapshot()
      .firstWhere((x) => x is HeapSnapshot);
    List<ObjectVertex> vert = snapshot.graph.vertices.toList();
    vert.sort((a, b) => b.retainedSize.compareTo(a.retainedSize));
    var count = 0;
    for (ObjectVertex v in vert) {
      Class c = i.getClassByCid(v.vmCid);

      if (c == null) {
        continue;
      }

      ServiceObject object = await i.getObjectByAddress(v.address);

      var map = {
        "type": c.name,
        "retainedSize": v.retainedSize,
        "shallowSize": v.shallowSize,
        "objectId": object.id
      };

      if (object is Instance) {
        if (object.isMap || object.isList) {
          await object.reload();
          map["length"] = object.length;
        }

        if (object.isMap) {
          ObservableList list = object.associations;
          map["keys"] = list.map((x) {
            dynamic key = x["key"];
            if (key is Instance) {
              return key.valueAsString;
            } else {
              return null;
            }
          }).where((x) => x != null).toList();
        }
      }

      output.add(map);
      count++;

      if (count % 1000 == 0) {
        print("== Visited ${count} out of ${vert.length} objects. ==");
      }
    }
  }

  var out = {
    "timestamp": heapTimestamp.toString(),
    "isolateId": i.id,
    "snapshot": output
  };

  var packer = new StatefulPacker();
  packer.pack(out);
  await outputFile.writeAsBytes(packer.done());

  print("== Success: Snapshot Generated. ==");
  exit(0);
}
