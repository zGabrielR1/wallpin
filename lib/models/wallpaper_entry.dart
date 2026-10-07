/// One cached / applied wallpaper entry.
class WallpaperEntry {
  final String id; // Pinterest pin id or hash of URL
  final String pageUrl; // https://www.pinterest.com/pin/<id>/
  final String imageUrl; // directorig image URL
  final String? title;
  final DateTime savedAt;
  final String localPath; // file in app cache dir

  WallpaperEntry({
    required this.id,
    required this.pageUrl,
    required this.imageUrl,
    required this.savedAt,
    required this.localPath,
    this.title,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'pageUrl': pageUrl,
        'imageUrl': imageUrl,
        'title': title,
        'savedAt': savedAt.toIso8601String(),
        'localPath': localPath,
      };

  factory WallpaperEntry.fromJson(Map<String, dynamic> j) => WallpaperEntry(
        id: j['id'] as String,
        pageUrl: j['pageUrl'] as String,
        imageUrl: j['imageUrl'] as String,
        title: j['title'] as String?,
        savedAt: DateTime.parse(j['savedAt'] as String),
        localPath: j['localPath'] as String,
      );
}
