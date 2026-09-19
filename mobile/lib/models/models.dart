int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

double asDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.points = 0,
    this.level = 1,
    this.tier = 1,
    this.tierName = 'Pemula',
    this.pointsToNext = 50,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final int points;
  final int level;
  final int tier;
  final String tierName;
  final int pointsToNext;

  bool get isOwner => role == 'owner';
  bool get isOperator => role == 'operator';
  bool get isAdmin => role == 'admin' || role == 'superadmin';
  bool get canBook => role == 'user' || role == 'owner';
  /// Event boleh dibuat semua user login (mode pelapak); admin/owner selalu.
  bool get canCreateEvent => role == 'user' || isOwner || isAdmin;
  bool get canInputWeight => isOperator || isAdmin;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: asInt(json['id']),
        name: '${json['name'] ?? ''}',
        email: '${json['email'] ?? ''}',
        role: '${json['role'] ?? ''}',
        points: asInt(json['points']),
        level: asInt(json['level']).clamp(1, 30),
        tier: asInt(json['tier']).clamp(1, 10),
        tierName: '${json['tier_name'] ?? 'Pemula'}',
        pointsToNext: asInt(json['points_to_next']),
      );
}

class FishingEvent {
  const FishingEvent({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.rentalEnabled,
    required this.bookingsCount,
    this.stallId,
    this.stallName = '',
    this.maxParticipants = 0,
    this.category = 'galatama',
    this.registrationFee = 0,
    this.participantsCount = 0,
    this.rentalLocked = false,
    this.latitude,
    this.longitude,
  });

  final int id;
  final int ownerId;
  final String ownerName;
  final String title;
  final String description;
  final String date;
  final String location;
  final bool rentalEnabled;
  final int bookingsCount;
  final int? stallId;
  final String stallName;
  final int maxParticipants;
  final String category;
  final int registrationFee;
  final int participantsCount;
  final bool rentalLocked;
  final double? latitude;
  final double? longitude;

  factory FishingEvent.fromJson(Map<String, dynamic> json) {
    double? lat;
    double? lng;
    if (json['latitude'] != null) lat = asDouble(json['latitude']);
    if (json['longitude'] != null) lng = asDouble(json['longitude']);
    return FishingEvent(
      id: asInt(json['id']),
      ownerId: asInt(json['owner_id']),
      ownerName: '${json['owner_name'] ?? ''}',
      title: '${json['title'] ?? ''}',
      description: '${json['description'] ?? ''}',
      date: '${json['date'] ?? ''}',
      location: '${json['location'] ?? ''}',
      rentalEnabled: json['rental_enabled'] == true || json['rental_enabled'] == 1,
      bookingsCount: asInt(json['bookings_count']),
      stallId: json['stall_id'] == null ? null : asInt(json['stall_id']),
      stallName: '${json['stall_name'] ?? ''}',
      maxParticipants: asInt(json['max_participants']),
      category: '${json['category'] ?? 'galatama'}',
      registrationFee: asInt(json['registration_fee']),
      participantsCount: asInt(json['participants_count']),
      rentalLocked: json['rental_locked'] == true || json['rental_locked'] == 1,
      latitude: lat,
      longitude: lng,
    );
  }
}

class Stall {
  const Stall({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.location,
    required this.dailyRentPrice,
    required this.active,
    this.capacity = 10,
    this.harianEnabled = false,
    this.scheme = 'kilogebrus',
    this.bookedSlots = 0,
    this.remainingSlots = 0,
    this.available = true,
    this.blockedByEvent = false,
    this.notOpenOnDate = false,
  });

  final int id;
  final int ownerId;
  final String name;
  final String description;
  final String location;
  final int dailyRentPrice;
  final bool active;
  final int capacity;
  final bool harianEnabled;
  final String scheme;
  final int bookedSlots;
  final int remainingSlots;
  final bool available;
  final bool blockedByEvent;
  final bool notOpenOnDate;

  String get schemeLabel => switch (scheme) {
        'borongan' => 'Borongan',
        'kilogebrus_borongan' => 'Kilogebrus + Borongan',
        _ => 'Kilogebrus',
      };

  factory Stall.fromJson(Map<String, dynamic> json) => Stall(
        id: asInt(json['id']),
        ownerId: asInt(json['owner_id']),
        name: '${json['name'] ?? ''}',
        description: '${json['description'] ?? ''}',
        location: '${json['location'] ?? ''}',
        dailyRentPrice: asInt(json['daily_rent_price']),
        active: json['active'] == true || json['active'] == 1,
        capacity: asInt(json['capacity']).clamp(1, 9999),
        harianEnabled: json['harian_enabled'] == true || json['harian_enabled'] == 1,
        scheme: '${json['scheme'] ?? 'kilogebrus'}',
        bookedSlots: asInt(json['booked_slots']),
        remainingSlots: asInt(json['remaining_slots']),
        available: json['available'] == true || json['available'] == 1 || json['available'] == null,
        blockedByEvent: json['blocked_by_event'] == true || json['blocked_by_event'] == 1,
        notOpenOnDate: json['not_open_on_date'] == true || json['not_open_on_date'] == 1,
      );
}

class StallDayAvailability {
  const StallDayAvailability({
    required this.date,
    required this.capacity,
    required this.bookedSlots,
    required this.remainingSlots,
    required this.available,
    required this.blockedByEvent,
    this.notOpenOnDate = false,
  });

  final String date;
  final int capacity;
  final int bookedSlots;
  final int remainingSlots;
  final bool available;
  final bool blockedByEvent;
  final bool notOpenOnDate;

  factory StallDayAvailability.fromJson(Map<String, dynamic> json) => StallDayAvailability(
        date: '${json['date'] ?? ''}'.length >= 10 ? '${json['date']}'.substring(0, 10) : '${json['date'] ?? ''}',
        capacity: asInt(json['capacity']),
        bookedSlots: asInt(json['booked_slots']),
        remainingSlots: asInt(json['remaining_slots']),
        available: json['available'] == true || json['available'] == 1,
        blockedByEvent: json['blocked_by_event'] == true || json['blocked_by_event'] == 1,
        notOpenOnDate: json['not_open_on_date'] == true || json['not_open_on_date'] == 1,
      );
}

class EventRegistration {
  const EventRegistration({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.userId,
    required this.userName,
    required this.status,
    required this.amount,
    this.paymentProvider = 'xendit',
  });

  final int id;
  final int eventId;
  final String eventTitle;
  final int userId;
  final String userName;
  final String status;
  final int amount;
  final String paymentProvider;

  factory EventRegistration.fromJson(Map<String, dynamic> json) => EventRegistration(
        id: asInt(json['id']),
        eventId: asInt(json['event_id']),
        eventTitle: '${json['event_title'] ?? ''}',
        userId: asInt(json['user_id']),
        userName: '${json['user_name'] ?? ''}',
        status: '${json['status'] ?? ''}',
        amount: asInt(json['amount']),
        paymentProvider: '${json['payment_provider'] ?? 'xendit'}',
      );
}

class Booking {
  const Booking({
    required this.id,
    this.eventId,
    required this.eventTitle,
    required this.userId,
    required this.userName,
    this.stallId,
    required this.stallName,
    this.stallLocation = '',
    this.dailyRentPrice = 0,
    this.rentalDate = '',
    required this.status,
  });

  final int id;
  final int? eventId;
  final String eventTitle;
  final int userId;
  final String userName;
  final int? stallId;
  final String stallName;
  final String stallLocation;
  final int dailyRentPrice;
  final String rentalDate;
  final String status;

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: asInt(json['id']),
        eventId: json['event_id'] == null ? null : asInt(json['event_id']),
        eventTitle: '${json['event_title'] ?? ''}',
        userId: asInt(json['user_id']),
        userName: '${json['user_name'] ?? ''}',
        stallId: json['stall_id'] == null ? null : asInt(json['stall_id']),
        stallName: '${json['stall_name'] ?? ''}',
        stallLocation: '${json['stall_location'] ?? ''}',
        dailyRentPrice: asInt(json['daily_rent_price']),
        rentalDate: '${json['rental_date'] ?? ''}'.length >= 10
            ? '${json['rental_date']}'.substring(0, 10)
            : '${json['rental_date'] ?? ''}',
        status: '${json['status'] ?? ''}',
      );
}

class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.weight,
  });

  final int id;
  final int eventId;
  final int userId;
  final String userName;
  final double weight;

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        id: asInt(json['id']),
        eventId: asInt(json['event_id']),
        userId: asInt(json['user_id']),
        userName: '${json['user_name'] ?? ''}',
        weight: asDouble(json['weight']),
      );
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.caption,
    required this.location,
    this.latitude,
    this.longitude,
    required this.imageUrl,
    required this.imageUrls,
    required this.commentsCount,
    required this.likesCount,
    required this.likedByMe,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String userName;
  final String caption;
  final String location;
  final double? latitude;
  final double? longitude;
  final String imageUrl;
  final List<String> imageUrls;
  final int commentsCount;
  final int likesCount;
  final bool likedByMe;
  final String createdAt;

  List<String> get mediaUrls {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (imageUrl.isNotEmpty) return [imageUrl];
    return const [];
  }

  FeedPost copyWith({int? likesCount, bool? likedByMe, int? commentsCount}) => FeedPost(
        id: id,
        userId: userId,
        userName: userName,
        caption: caption,
        location: location,
        latitude: latitude,
        longitude: longitude,
        imageUrl: imageUrl,
        imageUrls: imageUrls,
        commentsCount: commentsCount ?? this.commentsCount,
        likesCount: likesCount ?? this.likesCount,
        likedByMe: likedByMe ?? this.likedByMe,
        createdAt: createdAt,
      );

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final urls = <String>[];
    final raw = json['image_urls'];
    if (raw is List) {
      for (final e in raw) {
        final s = '$e';
        if (s.isNotEmpty) urls.add(s);
      }
    }
    final single = '${json['image_url'] ?? ''}';
    double? lat;
    double? lng;
    if (json['latitude'] != null) lat = asDouble(json['latitude']);
    if (json['longitude'] != null) lng = asDouble(json['longitude']);
    return FeedPost(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      userName: '${json['user_name'] ?? ''}',
      caption: '${json['caption'] ?? ''}',
      location: '${json['location'] ?? ''}',
      latitude: lat,
      longitude: lng,
      imageUrl: single.isNotEmpty ? single : (urls.isNotEmpty ? urls.first : ''),
      imageUrls: urls.isNotEmpty ? urls : (single.isNotEmpty ? [single] : const []),
      commentsCount: asInt(json['comments_count']),
      likesCount: asInt(json['likes_count']),
      likedByMe: json['liked_by_me'] == true || json['liked_by_me'] == 1,
      createdAt: '${json['created_at'] ?? ''}',
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.role,
    this.points = 0,
    this.level = 1,
    this.tier = 1,
    this.tierName = 'Pemula',
    this.pointsToNext = 50,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.followedByMe,
    required this.isMe,
  });

  final int id;
  final String name;
  final String role;
  final int points;
  final int level;
  final int tier;
  final String tierName;
  final int pointsToNext;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool followedByMe;
  final bool isMe;

  UserProfile copyWith({
    int? followersCount,
    int? followingCount,
    bool? followedByMe,
  }) =>
      UserProfile(
        id: id,
        name: name,
        role: role,
        points: points,
        level: level,
        tier: tier,
        tierName: tierName,
        pointsToNext: pointsToNext,
        postsCount: postsCount,
        followersCount: followersCount ?? this.followersCount,
        followingCount: followingCount ?? this.followingCount,
        followedByMe: followedByMe ?? this.followedByMe,
        isMe: isMe,
      );

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: asInt(json['id']),
        name: '${json['name'] ?? ''}',
        role: '${json['role'] ?? ''}',
        points: asInt(json['points']),
        level: asInt(json['level']).clamp(1, 30),
        tier: asInt(json['tier']).clamp(1, 10),
        tierName: '${json['tier_name'] ?? 'Pemula'}',
        pointsToNext: asInt(json['points_to_next']),
        postsCount: asInt(json['posts_count']),
        followersCount: asInt(json['followers_count']),
        followingCount: asInt(json['following_count']),
        followedByMe: json['followed_by_me'] == true || json['followed_by_me'] == 1,
        isMe: json['is_me'] == true || json['is_me'] == 1,
      );
}

class EventAward {
  const EventAward({
    required this.userId,
    required this.userName,
    required this.place,
    required this.points,
    this.weight = 0,
    this.awarded = false,
  });

  final int userId;
  final String userName;
  final int place;
  final int points;
  final double weight;
  final bool awarded;

  factory EventAward.fromJson(Map<String, dynamic> json) => EventAward(
        userId: asInt(json['user_id']),
        userName: '${json['user_name'] ?? ''}',
        place: asInt(json['place']),
        points: asInt(json['points']),
        weight: asDouble(json['weight']),
        awarded: json['awarded'] == true || json['awarded'] == 1,
      );
}

class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.replyToName = '',
    this.likesCount = 0,
    this.likedByMe = false,
  });

  final int id;
  final int postId;
  final int userId;
  final String userName;
  final String body;
  final String createdAt;
  final int? parentId;
  final String replyToName;
  final int likesCount;
  final bool likedByMe;

  bool get isReply => parentId != null && parentId! > 0;

  PostComment copyWith({int? likesCount, bool? likedByMe}) => PostComment(
        id: id,
        postId: postId,
        userId: userId,
        userName: userName,
        body: body,
        createdAt: createdAt,
        parentId: parentId,
        replyToName: replyToName,
        likesCount: likesCount ?? this.likesCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: asInt(json['id']),
        postId: asInt(json['post_id']),
        userId: asInt(json['user_id']),
        userName: '${json['user_name'] ?? ''}',
        body: '${json['body'] ?? ''}',
        createdAt: '${json['created_at'] ?? ''}',
        parentId: json['parent_id'] == null ? null : asInt(json['parent_id']),
        replyToName: '${json['reply_to_name'] ?? ''}',
        likesCount: asInt(json['likes_count']),
        likedByMe: json['liked_by_me'] == true || json['liked_by_me'] == 1,
      );
}

List<Map<String, dynamic>> asObjectList(dynamic data) {
  if (data is! List) return [];
  return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}
