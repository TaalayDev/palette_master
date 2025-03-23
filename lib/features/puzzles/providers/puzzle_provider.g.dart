// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'puzzle_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$puzzleStateHash() => r'b0974cdc68565b0daaa7d9cb9d1b22828129bc1c';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$PuzzleState
    extends BuildlessAutoDisposeNotifier<AsyncValue<Puzzle?>> {
  late final String puzzleId;
  late final int level;

  AsyncValue<Puzzle?> build(
    String puzzleId,
    int level,
  );
}

/// See also [PuzzleState].
@ProviderFor(PuzzleState)
const puzzleStateProvider = PuzzleStateFamily();

/// See also [PuzzleState].
class PuzzleStateFamily extends Family<AsyncValue<Puzzle?>> {
  /// See also [PuzzleState].
  const PuzzleStateFamily();

  /// See also [PuzzleState].
  PuzzleStateProvider call(
    String puzzleId,
    int level,
  ) {
    return PuzzleStateProvider(
      puzzleId,
      level,
    );
  }

  @override
  PuzzleStateProvider getProviderOverride(
    covariant PuzzleStateProvider provider,
  ) {
    return call(
      provider.puzzleId,
      provider.level,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'puzzleStateProvider';
}

/// See also [PuzzleState].
class PuzzleStateProvider
    extends AutoDisposeNotifierProviderImpl<PuzzleState, AsyncValue<Puzzle?>> {
  /// See also [PuzzleState].
  PuzzleStateProvider(
    String puzzleId,
    int level,
  ) : this._internal(
          () => PuzzleState()
            ..puzzleId = puzzleId
            ..level = level,
          from: puzzleStateProvider,
          name: r'puzzleStateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$puzzleStateHash,
          dependencies: PuzzleStateFamily._dependencies,
          allTransitiveDependencies:
              PuzzleStateFamily._allTransitiveDependencies,
          puzzleId: puzzleId,
          level: level,
        );

  PuzzleStateProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.puzzleId,
    required this.level,
  }) : super.internal();

  final String puzzleId;
  final int level;

  @override
  AsyncValue<Puzzle?> runNotifierBuild(
    covariant PuzzleState notifier,
  ) {
    return notifier.build(
      puzzleId,
      level,
    );
  }

  @override
  Override overrideWith(PuzzleState Function() create) {
    return ProviderOverride(
      origin: this,
      override: PuzzleStateProvider._internal(
        () => create()
          ..puzzleId = puzzleId
          ..level = level,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        puzzleId: puzzleId,
        level: level,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<PuzzleState, AsyncValue<Puzzle?>>
      createElement() {
    return _PuzzleStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PuzzleStateProvider &&
        other.puzzleId == puzzleId &&
        other.level == level;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, puzzleId.hashCode);
    hash = _SystemHash.combine(hash, level.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PuzzleStateRef on AutoDisposeNotifierProviderRef<AsyncValue<Puzzle?>> {
  /// The parameter `puzzleId` of this provider.
  String get puzzleId;

  /// The parameter `level` of this provider.
  int get level;
}

class _PuzzleStateProviderElement
    extends AutoDisposeNotifierProviderElement<PuzzleState, AsyncValue<Puzzle?>>
    with PuzzleStateRef {
  _PuzzleStateProviderElement(super.provider);

  @override
  String get puzzleId => (origin as PuzzleStateProvider).puzzleId;
  @override
  int get level => (origin as PuzzleStateProvider).level;
}

String _$userMixedColorHash() => r'1dcb155cdf55e534d4cd2812e04fd5b4ef511797';

/// See also [UserMixedColor].
@ProviderFor(UserMixedColor)
final userMixedColorProvider =
    AutoDisposeNotifierProvider<UserMixedColor, Color>.internal(
  UserMixedColor.new,
  name: r'userMixedColorProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userMixedColorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserMixedColor = AutoDisposeNotifier<Color>;
String _$puzzleResultHash() => r'd6fd7ad6f7d1bb0f8edc4779ae3e8d28f40f1c39';

/// See also [PuzzleResult].
@ProviderFor(PuzzleResult)
final puzzleResultProvider =
    AutoDisposeNotifierProvider<PuzzleResult, AsyncValue<bool?>>.internal(
  PuzzleResult.new,
  name: r'puzzleResultProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$puzzleResultHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PuzzleResult = AutoDisposeNotifier<AsyncValue<bool?>>;
String _$gameProgressHash() => r'4d3cb89cfd53e090decb3d91eb13cc7d81c32bec';

/// See also [GameProgress].
@ProviderFor(GameProgress)
final gameProgressProvider =
    AutoDisposeNotifierProvider<GameProgress, Map<String, int>>.internal(
  GameProgress.new,
  name: r'gameProgressProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$gameProgressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GameProgress = AutoDisposeNotifier<Map<String, int>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
