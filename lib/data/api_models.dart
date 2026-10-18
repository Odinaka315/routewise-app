/// Data models representing responses and requests for the Routewise Backend.
library;

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
    this.isTimeout = false,
  });

  final String message;
  final int? statusCode;
  final bool isNetworkError;
  final bool isTimeout;

  @override
  String toString() => message;
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.refreshExpiresIn,
    this.tokenType = 'bearer',
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final int refreshExpiresIn;
  final String tokenType;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
      refreshExpiresIn: (json['refresh_expires_in'] as num).toInt(),
      tokenType: (json['token_type'] as String?) ?? 'bearer',
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_in': expiresIn,
        'refresh_expires_in': refreshExpiresIn,
        'token_type': tokenType,
      };
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    required this.emailVerified,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final bool emailVerified;
  final DateTime? createdAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      emailVerified: (json['email_verified'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'email_verified': emailVerified,
        'created_at': createdAt?.toIso8601String(),
      };
}

class GeocodeResult {
  const GeocodeResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.placeId,
    this.source,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? placeId;
  final String? source;

  factory GeocodeResult.fromJson(Map<String, dynamic> json) {
    return GeocodeResult(
      name: (json['name'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      placeId: (json['place_provider_id'] ?? json['provider_place_id']) as String?,
      source: (json['geocode_source'] ?? json['provider']) as String?,
    );
  }
}
