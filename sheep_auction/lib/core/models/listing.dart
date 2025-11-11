import 'package:flutter/foundation.dart';

/// Represents an auction listing for a registered sheep.
@immutable
class AuctionListing {
  const AuctionListing({
    required this.id,
    required this.sheepId,
    required this.createdBy,
    required this.createdAt,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.startingBid,
    this.reservePrice,
    this.summary,
    this.highlightTraits = const <String>[],
    this.mediaAssetIds = const <String>[],
    this.acceptedBidId,
  });

  final String id;
  final String sheepId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime startsAt;
  final DateTime endsAt;
  final ListingStatus status;
  final int startingBid;
  final int? reservePrice;
  final String? summary;
  final List<String> highlightTraits;
  final List<String> mediaAssetIds;
  final String? acceptedBidId;

  bool get isLive => status == ListingStatus.live;
  bool get isDraft => status == ListingStatus.draft;
  bool get isClosed => status == ListingStatus.closed || status == ListingStatus.settled;

  AuctionListing copyWith({
    String? summary,
    ListingStatus? status,
    int? startingBid,
    int? reservePrice,
    List<String>? highlightTraits,
    List<String>? mediaAssetIds,
    String? acceptedBidId,
  }) {
    return AuctionListing(
      id: id,
      sheepId: sheepId,
      createdBy: createdBy,
      createdAt: createdAt,
      startsAt: startsAt,
      endsAt: endsAt,
      status: status ?? this.status,
      startingBid: startingBid ?? this.startingBid,
      reservePrice: reservePrice ?? this.reservePrice,
      summary: summary ?? this.summary,
      highlightTraits: highlightTraits ?? this.highlightTraits,
      mediaAssetIds: mediaAssetIds ?? this.mediaAssetIds,
      acceptedBidId: acceptedBidId ?? this.acceptedBidId,
    );
  }
}

enum ListingStatus {
  draft,
  live,
  soldPending,
  settled,
  disputed,
  closed,
}
