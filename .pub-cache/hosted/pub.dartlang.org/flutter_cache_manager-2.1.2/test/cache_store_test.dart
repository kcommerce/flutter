import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/src/cache_store.dart';
import 'package:flutter_cache_manager/src/storage/cache_object.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_cache_manager/src/storage/cache_info_repositories'
    '/cache_info_repository.dart';
import 'helpers/config_extensions.dart';

import 'helpers/test_configuration.dart';

void main() {
  group('Retrieving files from store', () {
    test('Store should return null when file not cached', () async {
      var repo = MockRepo();
      when(repo.get(any)).thenAnswer((_) => Future.value(null));
      var store = CacheStore(createTestConfig());

      expect(await store.getFile('This is a test'), null);
    });

    test('Store should return FileInfo when file is cached', () async {
      var fileName = 'testimage.png';
      var fileUrl = 'baseflow.com/test.png';

      var config = createTestConfig();
      await config.returnsFile(fileName);
      config.returnsCacheObject(fileUrl, fileName, DateTime.now());

      var tempDir = createDir();
      await (await tempDir).childFile('testimage.png').create();

      var store = CacheStore(config);

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);
    });

    test('Store should return null when file is no longer cached', () async {
      var repo = MockRepo();

      when(repo.get('baseflow.com/test.png')).thenAnswer((_) => Future.value(
          CacheObject('baseflow.com/test.png', relativePath: 'testimage.png')));
      var store = CacheStore(createTestConfig());

      expect(await store.getFile('baseflow.com/test.png'), null);
    });

    test('Store should return no CacheInfo when file not cached', () async {
      var repo = MockRepo();
      when(repo.get(any)).thenAnswer((_) => Future.value(null));
      var store = CacheStore(createTestConfig());

      expect(await store.retrieveCacheData('This is a test'), null);
    });

    test('Store should return CacheInfo when file is cached', () async {
      var fileName = 'testimage.png';
      var fileUrl = 'baseflow.com/test.png';

      var config = createTestConfig();
      await config.returnsFile(fileName);
      config.returnsCacheObject(fileUrl, fileName, DateTime.now());

      var store = CacheStore(config);

      expect(await store.retrieveCacheData(fileUrl), isNotNull);
    });

    test('Store should return CacheInfo from memory when asked twice',
        () async {
      var fileName = 'testimage.png';
      var fileUrl = 'baseflow.com/test.png';
      var validTill = DateTime.now();
      var config = createTestConfig();

      await config.returnsFile(fileName);
      config.returnsCacheObject(fileUrl, fileName, validTill);
      var store = CacheStore(config);

      var result = await store.retrieveCacheData(fileUrl);
      expect(result, isNotNull);
      var _ = await store.retrieveCacheData(fileUrl);
      verify(config.repo.get(any)).called(1);
    });

    test(
        'Store should return File from memcache only when file is retrieved before',
        () async {
      var fileName = 'testimage.png';
      var fileUrl = 'baseflow.com/test.png';
      var validTill = DateTime.now();
      var config = createTestConfig();

      await config.returnsFile(fileName);
      config.returnsCacheObject(fileUrl, fileName, validTill);

      var store = CacheStore(config);

      expect(await store.getFileFromMemory(fileUrl), null);
      await store.getFile(fileUrl);
      expect(await store.getFileFromMemory(fileUrl), isNotNull);
    });
  });

  group('Storing files in store', () {
    test('Store should store fileinfo in repo', () async {
      var config = createTestConfig();
      var store = CacheStore(config);

      var cacheObject =
          CacheObject('baseflow.com/test.png', relativePath: 'testimage.png');
      await store.putFile(cacheObject);

      verify(config.repo.updateOrInsert(cacheObject)).called(1);
    });
  });

  group('Removing files in store', () {
    test('Store should remove fileinfo from repo on delete', () async {
      var fileName = 'testimage.png';
      var fileUrl = 'baseflow.com/test.png';
      var validTill = DateTime.now();
      var config = createTestConfig();

      await config.returnsFile(fileName);
      config.returnsCacheObject(fileUrl, fileName, validTill);

      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);

      var cacheObject = CacheObject(fileUrl, relativePath: fileName, id: 1);
      await store.removeCachedFile(cacheObject);

      verify(config.repo.deleteAll(argThat(contains(cacheObject.id))))
          .called(1);
    });

    test('Store should remove file over capacity', () async {
      var config = createTestConfig();
      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);

      var cacheObject = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage.png', id: 1);
      await config.returnsFile('testimage.png');

      when(config.repo.getObjectsOverCapacity(any))
          .thenAnswer((_) => Future.value([cacheObject]));
      when(config.repo.getOldObjects(any)).thenAnswer((_) => Future.value([]));
      when(config.repo.get('baseflow.com/test.png'))
          .thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);

      await untilCalled(config.repo.deleteAll(any));

      verify(config.repo.getObjectsOverCapacity(any)).called(1);
      verify(config.repo.deleteAll(argThat(contains(cacheObject.id))))
          .called(1);
    });

    test('Store should remove file over that are too old', () async {
      var config = createTestConfig();
      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);
      await config.returnsFile('testimage.png');

      var cacheObject = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage.png', id: 1);

      when(config.repo.getObjectsOverCapacity(any))
          .thenAnswer((_) => Future.value([]));
      when(config.repo.getOldObjects(any))
          .thenAnswer((_) => Future.value([cacheObject]));
      when(config.repo.get('baseflow.com/test.png'))
          .thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);

      await untilCalled(config.repo.deleteAll(any));

      verify(config.repo.getOldObjects(any)).called(1);
      verify(config.repo.deleteAll(argThat(contains(cacheObject.id))))
          .called(1);
    });

    test('Store should remove file old and over capacity', () async {
      var config = createTestConfig();
      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);
      await config.returnsFile('testimage.png');

      var cacheObject = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage.png', id: 1);

      when(config.repo.getObjectsOverCapacity(any))
          .thenAnswer((_) => Future.value([cacheObject]));
      when(config.repo.getOldObjects(any))
          .thenAnswer((_) => Future.value([cacheObject]));
      when(config.repo.get('baseflow.com/test.png'))
          .thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);

      await untilCalled(config.repo.deleteAll(any));
      await Future.delayed(const Duration(milliseconds: 5));

      verify(config.repo.getObjectsOverCapacity(any)).called(1);
      verify(config.repo.getOldObjects(any)).called(1);
      verify(config.repo.deleteAll(argThat(contains(cacheObject.id))))
          .called(1);
    });

    test('Store should recheck cache info when file is removed', () async {
      var config = createTestConfig();
      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);
      var file = await config.returnsFile('testimage.png');

      var cacheObject = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage.png', id: 1);

      when(config.repo.getObjectsOverCapacity(any))
          .thenAnswer((_) => Future.value([]));
      when(config.repo.getOldObjects(any)).thenAnswer((_) => Future.value([]));
      when(config.repo.get('baseflow.com/test.png'))
          .thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);
      await file.delete();
      expect(await store.getFile('baseflow.com/test.png'), isNull);
    });

    test('Store should not remove files that are not old or over capacity',
        () async {
      var config = createTestConfig();
      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);
      await config.returnsFile('testimage.png');

      var cacheObject = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage.png', id: 1);

      when(config.repo.getObjectsOverCapacity(any))
          .thenAnswer((_) => Future.value([]));
      when(config.repo.getOldObjects(any)).thenAnswer((_) => Future.value([]));
      when(config.repo.get('baseflow.com/test.png'))
          .thenAnswer((_) => Future.value(cacheObject));

      expect(await store.getFile('baseflow.com/test.png'), isNotNull);

      await untilCalled(config.repo.deleteAll(any));

      verify(config.repo.getOldObjects(any)).called(1);
      verifyNever(config.repo.deleteAll(argThat(contains(cacheObject.id))));
    });

    test('Store should remove all files when emptying cache', () async {
      var config = createTestConfig();
      var store = CacheStore(config);
      store.cleanupRunMinInterval = const Duration(milliseconds: 1);
      await config.returnsFile('testimage.png');

      var co1 = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage1.png', id: 1);
      var co2 = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage2.png', id: 2);
      var co3 = CacheObject('baseflow.com/test.png',
          relativePath: 'testimage3.png', id: 3);

      when(config.repo.getAllObjects())
          .thenAnswer((_) => Future.value([co1, co2, co3]));

      await store.emptyCache();

      verify(config.repo
          .deleteAll(argThat(containsAll([co1.id, co2.id, co3.id])))).called(1);
    });
  });
}

Future<Directory> createDir() async {
  final fileSystem = MemoryFileSystem();
  return fileSystem.systemTempDirectory.createTemp('test');
}

class MockRepo extends Mock implements CacheInfoRepository {}
