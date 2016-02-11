import "dart:async";
import "dart:io";
import "dart:convert";

import "package:vm_service/service_io.dart";
import "package:vm_service/object_graph.dart";
import "package:observe/observe.dart";

const bool PRETTY = false;
const String URL = "ws://127.0.0.1:5938/ws";
const String ISOLATE = "isolates/754286013";

main() async {
  WebSocketVMTarget target = new WebSocketVMTarget(URL);
  WebSocketVM vm = new WebSocketVM(target);
  vm = await vm.load();
  Isolate i = await vm.getIsolate(ISOLATE);

  await i.getClassRefs();

  var output = [];

  {
    HeapSnapshot snapshot = await i.fetchHeapSnapshot().firstWhere((x) => x is HeapSnapshot);
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
        print("Visited ${count} out of ${vert.length} objects.");
      }
    }
  }

  var out = {
    "snapshot": output
  };

  var encoded = PRETTY
    ? const JsonEncoder.withIndent("  ").convert(out)
    : JSON.encode(out);
  await new File("profile.json").writeAsString(encoded);

  print("== Collection Complete ");
  print("== Collecting Statistics ==");
  print("${output.length} objects.");
  List<String> types = output.map((o) => o["type"]).toList();
  Set<String> typeSet = types.toSet();
  List<String> uniqueTypeList = typeSet.toList();
  print("${typeSet.length} unique types.");
  uniqueTypeList.sort((a, b) {
    var ac = 0;
    var bc = 0;

    for (String type in types) {
      if (type == a) {
        ac++;
      } else if (type == b) {
        bc++;
      }
    }

    return bc.compareTo(ac);
  });

  print("Most Common Types:");
  for (String type in uniqueTypeList.take(5)) {
    print("- ${type}");
  }
  print("== Snapshot Complete ==");
  exit(0);
}

Future<dynamic> deepCopy(input) async {
  if (input is Map) {
    var out = {};
    for (var key in input.keys) {
      out[await deepCopy(key)] = await deepCopy(input[key]);
    }
    return out;
  } else if (input is List) {
    var out = [];
    for (var e in input) {
      out.add(await deepCopy(e));
    }
    return out;
  } else if (input is Class) {
    await input.reload();
    return {
      "type": "Class",
      "name": input.name,
      "retainedSize": input.retainedSize,
      "bytesPromotedToOldGen": input.promotedByLastNewGC.bytes,
      "instancesPromotedToOldGen": input.promotedByLastNewGC.instances
    };
  } else {
    return input;
  }
}
