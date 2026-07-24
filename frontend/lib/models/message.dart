class Message {
  final int id;
  final int relationshipId;
  final int senderId;
  final String content;
  final bool isRead;
  final String? senderReaction;
  final String? receiverReaction;
  final DateTime createdAt;
  final int? replyToId;
  final Message? replyTo;

  Message({
    required this.id,
    required this.relationshipId,
    required this.senderId,
    required this.content,
    required this.isRead,
    this.senderReaction,
    this.receiverReaction,
    required this.createdAt,
    this.replyToId,
    this.replyTo,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      relationshipId: json['relationship_id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      content: json['content'] ?? '',
      isRead: json['is_read'] is int ? json['is_read'] == 1 : (json['is_read'] ?? false),
      senderReaction: json['sender_reaction'],
      receiverReaction: json['receiver_reaction'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      replyToId: json['reply_to_id'],
      replyTo: json['reply_to'] != null ? Message.fromJson(json['reply_to']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'relationship_id': relationshipId,
      'sender_id': senderId,
      'content': content,
      'is_read': isRead,
      'sender_reaction': senderReaction,
      'receiver_reaction': receiverReaction,
      'created_at': createdAt.toIso8601String(),
      'reply_to_id': replyToId,
      'reply_to': replyTo?.toJson(),
    };
  }

  Message copyWith({
    int? id,
    int? relationshipId,
    int? senderId,
    String? content,
    bool? isRead,
    String? senderReaction,
    String? receiverReaction,
    bool clearSenderReaction = false,
    bool clearReceiverReaction = false,
    DateTime? createdAt,
    int? replyToId,
    Message? replyTo,
  }) {
    return Message(
      id: id ?? this.id,
      relationshipId: relationshipId ?? this.relationshipId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      senderReaction: clearSenderReaction ? null : (senderReaction ?? this.senderReaction),
      receiverReaction: clearReceiverReaction ? null : (receiverReaction ?? this.receiverReaction),
      createdAt: createdAt ?? this.createdAt,
      replyToId: replyToId ?? this.replyToId,
      replyTo: replyTo ?? this.replyTo,
    );
  }
}
