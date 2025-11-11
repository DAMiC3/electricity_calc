import 'package:flutter/foundation.dart';

import 'user.dart';

/// Represents an auction listing for an app template or source code package.
@immutable
class AuctionListing {
  const AuctionListing({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.createdBy,
    required this.createdAt,
    required this.startsAt,
    required this.endsAt,
    required this.hashFingerprint,
    required this.status,
    this.reservePrice,
    this.startingBid = 0,
    this.attachments = const <ListingAttachment>[],
    this.demoAssets = const <DemoAsset>[],
    this.valuation,
    this.acceptedBidId,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String summary;
  final String category;
  final String createdBy;
  final DateTime createdAt;
  final DateTime startsAt;
  final DateTime endsAt;
  final ListingStatus status;
  final int startingBid;
  final int? reservePrice;
  final String hashFingerprint;
  final List<ListingAttachment> attachments;
  final List<DemoAsset> demoAssets;
  final ValuationEstimate? valuation;
  final String? acceptedBidId;
  final List<String> tags;

  bool get isLive => status == ListingStatus.live;
  bool get isDraft => status == ListingStatus.draft;
  bool get isClosed => status == ListingStatus.closed || status == ListingStatus.settled;

  AuctionListing copyWith({
    String? summary,
    ListingStatus? status,
    int? startingBid,
    int? reservePrice,
    List<ListingAttachment>? attachments,
    List<DemoAsset>? demoAssets,
    ValuationEstimate? valuation,
    String? acceptedBidId,
    List<String>? tags,
  }) {
    return AuctionListing(
      id: id,
      title: title,
      summary: summary ?? this.summary,
      category: category,
      createdBy: createdBy,
      createdAt: createdAt,
      startsAt: startsAt,
      endsAt: endsAt,
      status: status ?? this.status,
      startingBid: startingBid ?? this.startingBid,
      reservePrice: reservePrice ?? this.reservePrice,
      hashFingerprint: hashFingerprint,
      attachments: attachments ?? this.attachments,
      demoAssets: demoAssets ?? this.demoAssets,
      valuation: valuation ?? this.valuation,
      acceptedBidId: acceptedBidId ?? this.acceptedBidId,
      tags: tags ?? this.tags,
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

@immutable
class ListingAttachment {
  const ListingAttachment({
    required this.id,
    required this.name,
    required this.sizeInBytes,
    required this.hash,
    required this.uploadedAt,
    required this.storageUri,
    this.previewUrl,
  });

  final String id;
  final String name;
  final int sizeInBytes;
  final String hash;
  final DateTime uploadedAt;
  final String storageUri;
  final String? previewUrl;
}

enum DemoAssetType {
  webLink,
  sandboxSession,
  video,
  download,
}

@immutable
class DemoAsset {
  const DemoAsset({
    required this.id,
    required this.type,
    required this.label,
    required this.uri,
    this.expiresAt,
    this.isTimeLimited = false,
  });

  final String id;
  final DemoAssetType type;
  final String label;
  final String uri;
  final DateTime? expiresAt;
  final bool isTimeLimited;
}

@immutable
class ValuationEstimate {
  const ValuationEstimate({
    required this.minimum,
    required this.maximum,
    required this.confidence,
    this.notes,
  }) : assert(minimum <= maximum, 'Minimum valuation must not exceed maximum.');

  final int minimum;
  final int maximum;
  final double confidence;
  final String? notes;
}
