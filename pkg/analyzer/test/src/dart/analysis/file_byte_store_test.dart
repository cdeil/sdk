// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:typed_data';

import 'package:analyzer/src/dart/analysis/file_byte_store.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(EvictingFileByteStoreTest);
    defineReflectiveTests(FileByteStoreValidatorTest);
  });
}

@reflectiveTest
class EvictingFileByteStoreTest {
  late Directory tempDirectory;

  void setUp() {
    tempDirectory = Directory.systemTemp.createTempSync('evicting_byte_store');
  }

  void tearDown() {
    tempDirectory.deleteSync(recursive: true);
  }

  Future<void> test_startUpScan_skippedAfterRecentCleanUp() async {
    var first = EvictingFileByteStore(tempDirectory.path, 1024 * 1024);
    await first.cleanUpFutureForTesting;
    expect(first.cleanUpCount, 1);
    var stamp = File(
      join(tempDirectory.path, EvictingFileByteStore.cleanUpStampName),
    );
    expect(stamp.existsSync(), isTrue);

    var second = EvictingFileByteStore(tempDirectory.path, 1024 * 1024);
    expect(second.cleanUpFutureForTesting, isNull);
    expect(second.cleanUpCount, 0);

    stamp.setLastModifiedSync(
      DateTime.now().subtract(const Duration(hours: 2)),
    );
    var third = EvictingFileByteStore(tempDirectory.path, 1024 * 1024);
    await third.cleanUpFutureForTesting;
    expect(third.cleanUpCount, 1);
  }

  Future<void> test_startUpScan_ignoresStamp() async {
    var store = EvictingFileByteStore(tempDirectory.path, 1024 * 1024);
    await store.cleanUpFutureForTesting;
    expect(store.lastScannedFileCount, 0);
  }
}

@reflectiveTest
class FileByteStoreValidatorTest {
  final validator = FileByteStoreValidator();

  test_get_bad_notEnoughBytes() {
    var bytes = Uint8List.fromList([1, 2, 3]);
    var data = validator.getData(bytes);
    expect(data, isNull);
  }

  test_get_bad_notEnoughBytes_zero() {
    var bytes = Uint8List.fromList([]);
    var data = validator.getData(bytes);
    expect(data, isNull);
  }

  test_get_bad_wrongChecksum() {
    var data = Uint8List.fromList([1, 2, 3]);
    var bytes = validator.wrapData(data);

    // Damage the checksum.
    expect(bytes[bytes.length - 1], isNot(42));
    bytes[bytes.length - 1] = 42;

    var data2 = validator.getData(bytes);
    expect(data2, isNull);
  }

  test_get_bad_wrongVersion() {
    var bytes = Uint8List.fromList([
      0xBA,
      0xDA,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);
    var data = validator.getData(bytes);
    expect(data, isNull);
  }

  test_get_good() {
    var data = Uint8List.fromList([1, 2, 3]);
    var bytes = validator.wrapData(data);
    var data2 = validator.getData(bytes);
    expect(data2, hasLength(3));
    expect(data2, data);
  }

  test_get_good_zeroBytesData() {
    var data = Uint8List.fromList([]);
    var bytes = validator.wrapData(data);
    var data2 = validator.getData(bytes);
    expect(data2, hasLength(0));
    expect(data2, data);
  }
}
