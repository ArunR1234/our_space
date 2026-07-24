class Message {
  final int id;
  final int relationshipId;
  final int senderId;
  final String content;
  final bool isRead;
  final String? reaction;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.relationshipId,
    required this.senderId,
    required this.content,
    required this.isRead,
    this.reaction,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      relationshipId: json['relationship_id'],
      senderId: json['sender_id'],
      content: json['content'],
      isRead: json['is_read'] is int ? json['is_read'] == 1 : (json['is_read'] ?? false),
      reaction: json['reaction'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'relationship_id': relationshipId,
      'sender_id': senderId,
      'content': content,
      'is_read': isRead,
      'reaction': reaction,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Message copyWith({
    int? id,
    int? relationshipId,
    int? senderId,
    String? content,
    bool? isRead,
    String? reaction,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      relationshipId: relationshipId ?? this.relationshipId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      reaction: reaction ?? this.reaction,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
