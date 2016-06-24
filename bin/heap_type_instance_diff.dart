import "dart:io";
import "dart:convert";

main(List<String> args) async {
  var fileA = new File(args[0]);
  var fileB = new File(args[1]);
  var fileC = new File(args[2]);

  var jsonA = JSON.decode(await fileA.readAsString());
  var jsonB = JSON.decode(await fileB.readAsString());
  var jsonC = {};

  print(DateTime.parse(jsonA["timestamp"]).difference(DateTime.parse(jsonB["timestamp"])).abs().inHours);

  for (String key in jsonA["instances"].keys) {
    Map map = jsonA["instances"][key];
    int instances = map["old"];
    int newInstances = 0;
    if (jsonB["instances"][key] is Map) {
      newInstances = jsonB["instances"][key]["old"];
    }

    int grown = newInstances - instances;

    jsonC[key] = grown;
  }

  await fileC.writeAsString(const JsonEncoder.withIndent("  ").convert(jsonC));
}
