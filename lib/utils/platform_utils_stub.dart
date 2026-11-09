import 'platform_utils.dart';

abstract class BasePlatformUtils implements PlatformUtils {}

PlatformUtils getPlatformUtils() => throw UnsupportedError('Cannot create platform utils');
