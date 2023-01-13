import 'package:bili_novel_packer/epub_packer/epub_media_type.dart';
import 'package:bili_novel_packer/epub_packer/epub_opf.dart';
import 'package:test/test.dart';

void main() {
  test("EpubOpenPackageFormat Test", () {
    var opf = EpubOpenPackageFormat();
    opf.docTitle = "测试标题";
    opf.creator = "CXK";
    opf.uuid = "dffb4170-fc27-4122-9103-aec8afd91ab7";
    opf.addChapter(ManifestItem("chapter001", "chapter001.xhtml", EpubMediaType.xhtml));
    opf.addChapter(ManifestItem("chapter002", "chapter002.xhtml", EpubMediaType.xhtml));
    opf.addChapter(ManifestItem("chapter003", "chapter003.xhtml", EpubMediaType.xhtml));
    opf.addImage(ManifestItem("001.jpg", "images/001.jpg", EpubMediaType.jpg));
    opf.setCover("001.jpg");
    print(opf.build().toXmlString(pretty: true));
  });
}
