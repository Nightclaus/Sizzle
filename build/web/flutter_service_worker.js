'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "022881c60d7b4da17034320a5f1587a9",
"version.json": "c56591a9f602d0d3c7dfb75c80d02b5b",
"index.html": "ae3da005c54b58ecc4c78a258cb48f93",
"/": "ae3da005c54b58ecc4c78a258cb48f93",
"main.dart.js": "6644f22201de09eb790d3f2ece4c89fb",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"manifest.json": "eab946ebed5a4002d117778b24028b87",
".git/config": "eec9b4a559108a110b598d0ec5fce041",
".git/objects/61/29468cda53b67e3aaf5abd810b276556482c8d": "4f89cc95ba03ef1008ef5b8542241770",
".git/objects/57/7946daf6467a3f0a883583abfb8f1e57c86b54": "846aff8094feabe0db132052fd10f62a",
".git/objects/03/2fe904174b32b7135766696dd37e9a95c1b4fd": "80ba3eb567ab1b2327a13096a62dd17e",
".git/objects/35/96d08a5b8c249a9ff1eb36682aee2a23e61bac": "e931dda039902c600d4ba7d954ff090f",
".git/objects/3c/37ab325325d6e34a99c31b408730671ed7604d": "153689fd35dd5f3ba29f231b6044752f",
".git/objects/3c/ddf31c8f6efa4f8bf433aa27656f4e1da00e06": "8764738d87b028ae515b40f0ab50200d",
".git/objects/93/86f55abcd3a2bc8b4b299b8c7fe2d285b116c7": "06b9093bc9f85729166d2d5e15a20b4b",
".git/objects/5f/bf1f5ee49ba64ffa8e24e19c0231e22add1631": "f19d414bb2afb15ab9eb762fd11311d6",
".git/objects/d9/3952e90f26e65356f31c60fc394efb26313167": "1401847c6f090e48e83740a00be1c303",
".git/objects/df/cbcaf537c993dab7543741a1550c5304254fb0": "15f18b0b9f3d8978d769f947b21ba7dc",
".git/objects/a5/de584f4d25ef8aace1c5a0c190c3b31639895b": "9fbbb0db1824af504c56e5d959e1cdff",
".git/objects/bd/6be43d015a2a8a92db341ee519feb383a20cb4": "0df4c80430aff6e9b0cdd970bc215545",
".git/objects/d6/973b60663343c1581a9cc896775d45f3f5000c": "44c6f64ac6af7de5b586f9a07d7506dc",
".git/objects/d6/9c56691fbdb0b7efa65097c7cc1edac12a6d3e": "868ce37a3a78b0606713733248a2f579",
".git/objects/f3/709a83aedf1f03d6e04459831b12355a9b9ef1": "538d2edfa707ca92ed0b867d6c3903d1",
".git/objects/eb/9b4d76e525556d5d89141648c724331630325d": "37c0954235cbe27c4d93e74fe9a578ef",
".git/objects/c0/db2f9056071d3f16c578fe31cf8aa3654ffb19": "7185c6f37f5ab6f87f05980a56c9d9d8",
".git/objects/fd/6d7e11119124dec182d27fbc8d22a84edbe33b": "3909c0d4a2a5bfd723f6c31c1fac5757",
".git/objects/f2/04823a42f2d890f945f70d88b8e2d921c6ae26": "6b47f314ffc35cf6a1ced3208ecc857d",
".git/objects/f5/72b90ef57ee79b82dd846c6871359a7cb10404": "e68f5265f0bb82d792ff536dcb99d803",
".git/objects/20/b57305a7df31e9cf6367748335a1c01a696f9d": "00da483edbfcadeb80c1194cc1e3bbcc",
".git/objects/18/3b35dccea3b0dfacf4f02fb06f26a818cd8e4d": "d4f8648a8fd2e8e24ff0f184b45db8ec",
".git/objects/27/684db5e348db4c9043b575f7607681e6f5d945": "c58d100610ed14eff6808126456d5304",
".git/objects/16/a9583c1de62c1735d7adb6fdf1f004221c95ac": "113e0d7f29726901886424a4c07d6b12",
".git/objects/1f/34be3199a2bc4b19ab08b42151eff2d1ed0197": "afc4d27abea6798927a557b61d905698",
".git/objects/17/edc7e72423561f397cb5cf1aeecdf4748578dd": "7c4119c52524af118aa163d951c11eac",
".git/objects/8f/e829ce11c7e35d4367f0e1849be348fc403d14": "44b6942bca11d75ee1a0b71eeabbad5e",
".git/objects/8f/93b828b1c60df65e971f89057842fdf695cadf": "6d77499cd83b9b03296cb817960bfad6",
".git/objects/8a/51a9b155d31c44b148d7e287fc2872e0cafd42": "9f785032380d7569e69b3d17172f64e8",
".git/objects/8a/aa46ac1ae21512746f852a42ba87e4165dfdd1": "1d8820d345e38b30de033aa4b5a23e7b",
".git/objects/19/ffdfebb5f1b1fe5c18af9b0c137a700af05e52": "45fbb3d68f1f01b2590eccb28b44c02f",
".git/objects/88/f1399056f671119f0459fb41447c434d1a7d0d": "fc31ff74a1e5ef6a4dcb40e782d71810",
".git/objects/88/cfd48dff1169879ba46840804b412fe02fefd6": "e42aaae6a4cbfbc9f6326f1fa9e3380c",
".git/objects/6b/9862a1351012dc0f337c9ee5067ed3dbfbb439": "85896cd5fba127825eb58df13dfac82b",
".git/objects/00/100a3eb95bd983577e4fb3b1bf2b86149e3ba0": "b72a09d0596e73088ebf34d090a0b9da",
".git/objects/00/f66f02dfe2383bb4d405a8a66407e88d22d551": "2b4a300144d8698d83cda900e17739ed",
".git/objects/6e/85879e9dc9b1b8b7c4c1d8bc23c8a6427dc154": "5adb1385fd7f9e24556c1531d7f496a0",
".git/objects/5c/dedbcf13d44234abd941aa861957d4d0f218fe": "19d655b004cc08a235c034132ed72aed",
".git/objects/91/4a40ccb508c126fa995820d01ea15c69bb95f7": "8963a99a625c47f6cd41ba314ebd2488",
".git/objects/54/16d6a5d66ae921e690ec77816f4bad55b22ea4": "82cc7613c4ba5da40e07fd3f84c5a8a4",
".git/objects/98/4e9667bac553652987a6de26bfa83e43d0dbb1": "607360354f39a475cb27556c8528e841",
".git/objects/5e/bf37944a56f2b5e479e3858392c6e9030da2da": "d874f5ce1eb6512c7b77ebd17b676f00",
".git/objects/64/8addf362502ded12b84ef69820cad7fc14bb9a": "9b600d34aaccadceb1a0b95ecbd987c6",
".git/objects/d3/c4b8e49cde71b2e8cad5f645457404060987b6": "c7e780848c181be02c357b11537c7c9e",
".git/objects/d4/3532a2348cc9c26053ddb5802f0e5d4b8abc05": "3dad9b209346b1723bb2cc68e7e42a44",
".git/objects/dc/f83695f71da8c6278eb914cdd42692c427924e": "9ca7f32e12839dea4610032ada023058",
".git/objects/b7/49bfef07473333cf1dd31e9eed89862a5d52aa": "36b4020dca303986cad10924774fb5dc",
".git/objects/a8/8c9340e408fca6e68e2d6cd8363dccc2bd8642": "11e9d76ebfeb0c92c8dff256819c0796",
".git/objects/b9/2a0d854da9a8f73216c4a0ef07a0f0a44e4373": "f62d1eb7f51165e2a6d2ef1921f976f3",
".git/objects/ef/b875788e4094f6091d9caa43e35c77640aaf21": "27e32738aea45acd66b98d36fc9fc9e0",
".git/objects/f0/ed44169cf978a8bae8350c5842ce38faa69a65": "f90d7d512f2be2718d37ec481b72e369",
".git/objects/e9/94225c71c957162e2dcc06abe8295e482f93a2": "2eed33506ed70a5848a0b06f5b754f2c",
".git/objects/ce/e3c5bb4ad9ca1b7e02e3391cc1cbba998308b7": "8e23cc0d8eea61c17a30b19ec3ccb417",
".git/objects/ce/2a083e2fd26108c7e44b221a0cfb735435ef35": "52a9ac57893894ca6b912a8f946a7ee7",
".git/objects/2c/6714ebfa96584bc97716470a17631991963fb8": "6505c7ddf670cecccb5a7d4f3934f13c",
".git/objects/23/637bc3573701e2ad80a6f8be31b82926b4715f": "5f84f5c437bb2791fdc8411523eae8ff",
".git/objects/4f/02e9875cb698379e68a23ba5d25625e0e2e4bc": "254bc336602c9480c293f5f1c64bb4c7",
".git/objects/8d/75b7fc47cab35c5dc388f85d697ad4469ac7ca": "2e4675cd55c14b56b0543884cd42346d",
".git/objects/8d/5390e62c63ec65d9d45d6a0f3da76bad743770": "b184da1f8b893bb8c33e51880525e797",
".git/objects/49/5ec5b6ab91c5254da17e0a516ffa3bb345f25f": "0f3c5afa2baa617d0dbdec6c3190b5bf",
".git/objects/40/1184f2840fcfb39ffde5f2f82fe5957c37d6fa": "1ea653b99fd29cd15fcc068857a1dbb2",
".git/objects/8b/46c34192a45bdcd5ba40454461866f2a5381fe": "7b1d13230e198628d930c950f831cf92",
".git/objects/22/76ebfe6ce762f5f0e485e85861187f5255fad7": "e8379ebec62791d5465a537ff1fe0f29",
".git/HEAD": "cf7dd3ce51958c5f13fece957cc417fb",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/logs/HEAD": "e93c5b3b796d208378f9ab911f56525a",
".git/logs/refs/heads/main": "e93c5b3b796d208378f9ab911f56525a",
".git/logs/refs/remotes/origin/main": "d5474d347318328f5e9cfb977617831c",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/hooks/commit-msg.sample": "579a3c1e12a1e74a98169175fb913012",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/hooks/pre-commit.sample": "305eadbbcd6f6d2567e033ad12aabbc4",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/fsmonitor-watchman.sample": "a0b2633a2c8e97501610bd3f73da66fc",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/refs/heads/main": "a5c3fa984d96a9f15a55f84a23587fea",
".git/refs/remotes/origin/main": "a5c3fa984d96a9f15a55f84a23587fea",
".git/index": "49528e6e32bd39ceadea3a5e7602cc81",
".git/COMMIT_EDITMSG": "5c5973dc40c786c9b3aca3c2ae60b3c8",
"assets/AssetManifest.json": "5507947d601b857e15108f6842f640a0",
"assets/NOTICES": "ed98273ce8be4be2801d17f3533badc0",
"assets/FontManifest.json": "5a32d4310a6f5d9a6b651e75ba0d7372",
"assets/AssetManifest.bin.json": "2637004e3430977e9ad8aa904a2ca887",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/font_awesome_flutter/lib/fonts/fa-solid-900.ttf": "a2eb084b706ab40c90610942d98886ec",
"assets/packages/font_awesome_flutter/lib/fonts/fa-regular-400.ttf": "3ca5dc7621921b901d513cc1ce23788c",
"assets/packages/font_awesome_flutter/lib/fonts/fa-brands-400.ttf": "b6487389f90d347276eafbd2fe79dd6c",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "ccb5903fc29b6a2f6668311abd2d0558",
"assets/fonts/MaterialIcons-Regular.otf": "40353fc130bb6b26a595db0368b31811",
"assets/assets/harvest.jpg": "2ce013095435f868a262f52fbba7fe44",
"assets/assets/auto_ag_machine.png": "8c318edd19c80a16fe2fe0a0251bd487",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
