import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:bili_novel_packer/light_novel/base/light_novel_model.dart';
import 'package:bili_novel_packer/novel_packer.dart';
import 'package:bili_novel_packer/pack_argument.dart';
import 'package:bili_novel_packer/pack_callback.dart';
import 'package:console/console.dart';

const String gitUrl = "https://gitee.com/Montaro2017/bili_novel_packer";
const String version = "a0.1.2-M4";

String httpAuthToken = "";

void main(List<String> args) async {
  printWelcome();
  if (args.contains("-h") && args[0] == "-h") {
    int httpPort = int.parse(args.length >= 2 ? args[1] : '53001');
    print("[INFO] HTTP监听 http://0.0.0.0:$httpPort");
    if (args.contains("-token") && args[2] == "-token") {
      if(args.length >= 4 && args.contains(args[3])){
        httpAuthToken = args[3];
      }
    }

    HttpServer.bind(InternetAddress.anyIPv4, httpPort).then((server) {
      server.listen((HttpRequest request) async {
        String pathinfo = request.uri.toString();
        var uri = Uri.parse(pathinfo);
        var req = {};
        uri.queryParameters.forEach((k, v) {
          if (k == "url" || k == "cu") {
            req[k] = utf8.decode(base64Url.decode(v));
          } else if (k == "at") {
            req["at"] = v == "1";
          } else {
            req[k] = v;
          }
        });

        if (uri.path == "/") {
          request.response.headers.contentType =
              ContentType("application", "json", charset: "utf-8");
          request.response.write(jsonEncode({
            "mua": "来,先亲一个",
            "api": "http://0.0.0.0:$httpPort/api/push",
            "?query": {
              "url": "要采集的url地址(需要base64编码)",
              "cu": "回调的url地址(需要base64编码)",
              "at": "是否为每章添加标题?",
              "sv": "采集分卷范围(可输入如1-9进行范围选择以及如2,5单独选择,为空下载全部分卷)",
              "cu_f": "(e_e:事件完成,e_b:分卷采集开始,e_a:分卷采集结束,b:分卷采集结束是否携带章节内容进行回调)",
              "token": "访问token"
            }
          }));
        }
        if (httpAuthToken != "") {
          if (req.containsKey("token") == false ||
              httpAuthToken != req['token']) {
            request.response.write(jsonEncode({"code": 401, "err": "token错误"}));
            request.response.close();
            return;
          }
        }

        if (uri.path == "/api/push") {
          request.response.headers.contentType =
              ContentType("application", "json", charset: "utf-8");
          try {
            if (req['url'] == null) {
              throw Exception("url不能为空");
            }
            Console.write("\n");
            var novel = await startRun(
                // 采集地址
                req['url'],
                // 范围
                req['sv'] ?? "0",
                // 是否添加标题
                req['at'] ?? false,
                // 任务回调地址
                req['cu'] ?? "",
                // 任务回调配置 (b: 携带章节内容, e_b: 开始事件启用, e_a: 结束事件启用, e_e: 全部任务完成回调)
                req['cu_f'] ?? "e_e,e_b,e_a,b");
            Map<String, dynamic> info = {
              "code": 200,
              "data": novel,
              "params": {
                "sv": req['sv'] ?? "",
                "cu": req['cu'] ?? "",
                "at": req['at'] ?? ""
              }
            };
            request.response.write(jsonEncode(info));
          } catch (e) {
            request.response
                .write(jsonEncode({"code": 400, "err": e.toString()}));
          }
        }
        request.response.close();
      });
    });
    return;
  } else {
    start();
  }
}

void printWelcome() {
  print("===============================================================");
  print("欢迎使用轻小说打包器httpApi版!");
  print("作者: 喵金");
  print("当前版本: $version");
  print("如遇报错请先查看能否正常访问 https://w.linovelib.com");
  print(
      "否则请至开源地址携带报错信息进行反馈: https://github.com/u2nyakim/bili_novel_packer/tree/webapi");
  print("原版作者: Sparks");
  print("原版地址(鸣谢): $gitUrl");
  print("===============================================================");
  print("httpApi版启动命令:> bili_novel_packer-0.1.2-m4.exe -h 53001 -token\r\n");
  print("===============================================================");
}

class RunConsolePackCallback extends ConsolePackCallback {
  bool isDef = false;
  String cuAddress = "";
  List<String> cuContent = [];
  late Novel novel;

  // 耗时记录
  late Stopwatch stopwatch;

  @override
  void beforePackVolume(Volume volume) {
    if (cuContent.contains('e_b')) {
      event("packVolumeRun", {
        "volumeName": volume.volumeName,
        "volumePage": volume.volumePage,
      });
    }
    stopwatch = Stopwatch()..start();
    loadingBar.start();
  }

  @override
  void afterPackVolume(Volume volume) {
    stopwatch.stop();
    loadingBar.stop();
    loadingBar = LoadingBar();
    if (cuContent.contains('e_a')) {
      var chapters = [];
      for (int i = 0; i < volume.chapters.length; i++) {
        var item = {
          "name": volume.chapters[i].chapterName,
          "url": volume.chapters[1].chapterUrl
        };
        if (cuContent.contains('b')) {
          item['content'] = volume.chapters[1].chapterContent;
        }
        chapters.add(item);
      }
      event("packVolumeOk", {
        "volumeName": volume.volumeName,
        "volumePage": volume.volumePage,
        "milliseconds": stopwatch.elapsedMilliseconds,
        "chapters": volume.chapters
      });
    }
  }

  @override
  bool end() {
    if (cuContent.contains('e_e')) {
      event("packSuccess", {});
    }
    return isDef;
  }

  void event(String name, data) async {
    if (cuAddress != "") {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(cuAddress));
      request.headers.set(
          HttpHeaders.contentTypeHeader, "application/json; charset=UTF-8");
      request.write(jsonEncode({
        "code": 200,
        "data": data,
        "event": name,
        "id": novel.id,
      }));
      final response = await request.close();
      response.transform(utf8.decoder).listen((contents) {});
    }
  }
}

Future<Object> startRun(String srcUrl, String selectVolumeRange,
    bool chapterTitle, String callbackUrl, String callbackContent) async {
  var packer = NovelPacker.fromUrl(srcUrl);
  var novel = await packer.getNovel();
  Console.write("[${novel.id}]# 名称: ${novel.title}, 作者: ${novel.author}, 状态: ${novel.status}, 采集地址: $srcUrl, 采集范围: $selectVolumeRange, 回调配置: $callbackContent  \r\n");
  Catalog catalog = await packer.getCatalog();
  var volumes = [];
  for (int i = 0; i < catalog.volumes.length; i++) {
    catalog.volumes[i].volumePage = i + 1;
    volumes.add({"name": catalog.volumes[i].volumeName, "i": i + 1});
  }

  var arg = readPackArgument(catalog,
      def: true,
      setVolumeRange: selectVolumeRange,
      addChapterTitle: chapterTitle);
  var callback = RunConsolePackCallback();
  callback.isDef = true;
  callback.cuAddress = callbackUrl;
  callback.cuContent = callbackContent.split(",");
  callback.novel = novel;

  packer.pack(arg, callback);

  return {
    'title': novel.title,
    'url': srcUrl,
    'author': novel.author,
    'coverUrl': novel.coverUrl,
    'description': novel.description,
    'status': novel.status,
    'id': novel.id,
    'tags': novel.tags,
    "volumes": volumes
  };
}

void start() async {
  var url = readUrl();
  var packer = NovelPacker.fromUrl(url);
  printNovelDetail(await packer.getNovel());
  Catalog catalog = await packer.getCatalog();
  var arg = readPackArgument(catalog);
  packer.pack(arg, ConsolePackCallback());
}

String readUrl() {
  String? url;
  do {
    print("请输入URL(目前暂不支持直接输入id):");
    url = stdin.readLineSync();
  } while (url == null || url.isEmpty);
  return url;
}

void printNovelDetail(Novel novel) {
  Console.write("\n");
  Console.write(novel.toString());
}

PackArgument readPackArgument(Catalog catalog,
    {bool def = false,
    String setVolumeRange = '0',
    bool addChapterTitle = true}) {
  var arg = PackArgument();
  var select = readSelectVolume(catalog, def: def, input: setVolumeRange);
  arg.packVolumes = select;
  if (def == true) {
    arg.addChapterTitle = addChapterTitle;
    return arg;
  }
  Console.write("\n");

  arg.addChapterTitle =
      Chooser(["是", "否"], message: "是否为每章添加标题?").chooseSync() == "是";
  Console.write("\n");
  return arg;
}

List<Volume> readSelectVolume(Catalog catalog,
    {bool def = false, String? input = '0'}) {
  if (def == false) {
    Console.write("\n");
    for (int i = 0; i < catalog.volumes.length; i++) {
      Console.write("[${i + 1}] ${catalog.volumes[i].volumeName}\n");
    }
    Console.write("[0] 选择全部\n");
    Console.write(
      "请选择需要下载的分卷(可输入如1-9进行范围选择以及如2,5单独选择):",
    );
    input = Console.readLine();
  }

  List<Volume> selectVolumeIndex = [];

  if (input == null || input == "0") {
    for (int i = 0; i < catalog.volumes.length; i++) {
      selectVolumeIndex.add(catalog.volumes[i]);
    }
    return selectVolumeIndex;
  }
  List<String> parts = input.split(",");
  for (var part in parts) {
    List<String> range = part.split("-");
    if (range.length == 1) {
      int index = int.parse(range[0]) - 1;
      selectVolumeIndex.add(catalog.volumes[index]);
    } else {
      int from = int.parse(range[0]);
      int to = int.parse(range[1]);
      if (from > to) {
        int tmp = from;
        from = to;
        to = tmp;
      }
      for (int i = from; i <= to; i++) {
        int index = i - 1;
        selectVolumeIndex.add(catalog.volumes[index]);
      }
    }
  }
  return selectVolumeIndex;
}
