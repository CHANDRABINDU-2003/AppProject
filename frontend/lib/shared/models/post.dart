class Post {
  final int id;
  final int userId;
  final String text;
  final String? imageUrl;
  final int likes;

  Post({
    required this.id,
    required this.userId,
    required this.text,
    this.imageUrl,
    required this.likes,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j["id"],
        userId: j["user_id"],
        text: j["text"] ?? "",
        imageUrl: j["image_url"],
        likes: j["likes"] ?? 0,
      );

  Post copyWith({int? likes}) => Post(
        id: id,
        userId: userId,
        text: text,
        imageUrl: imageUrl,
        likes: likes ?? this.likes,
      );
}
