# Sample photos for snapshot fixtures

Real photographs that the iOS and Android snapshot tests draw wherever a screen shows a photo (posts, walls,
weeks, albums, collages, widgets, memories, avatars, group covers), so the recorded screens look like the app in use.
**Test data only:** they are read from this folder by test code and are never part of an app, extension or test bundle.

- **59 files**: 49 photos and 10 square portraits for avatars, 7.1 MB in total.
- **Source and licence:** every file comes from [Unsplash](https://unsplash.com) under the
  [Unsplash License](https://unsplash.com/license) (free use, no attribution required; see `LICENSE.md`). Each source
  page was checked to show "Free to use under the Unsplash License" (no Unsplash+ images). The photographers are
  credited below anyway.
- **Processing:** centre-cropped to the shape in the file name (avatars cropped around the face), resized to 1080 px
  on the long side (avatars 256 × 256), converted to sRGB, saved as JPEG quality 82 with **all metadata removed**
  (no EXIF, GPS, IPTC, XMP or ICC profile).
- **Content rules:** groups of friends, family, grandparents and kids, pets, food, trips, celebrations; day and night,
  warm and cool. No logos or brands, no celebrities, no text-heavy pictures, no AI-generated images.

## File names

`<what-it-shows>-<shape>.jpg`, where the shape is `3x4` (the app's own capture shape), `4x5`, `9x16`, `1x1`, `4x3`
or `3x2`; `avatar-NN.jpg` are the square portraits. Test helpers list the photos of a shape sorted by name, so picks
by index stay stable until a photo is added, removed or renamed; doing that changes the snapshots that use it, which
then have to be re-recorded on both platforms.

## How the tests load them

**iOS** (`ios/AppTests`): `Support/SamplePhotos.swift` finds this folder relative to `#filePath` (the same way
`SnapshotRecorder` finds `ios/build/snapshots`) and serves `image(named:)`, `data(named:)`, `url(named:)`,
`photo(index:orientation:)`, `photo(named:size:)` (centre-cropped to an exact pixel size, scale 1) and
`collage(size:names:columns:)`. Each group's support file maps its fixtures onto it:

| Group | Helper | What it feeds |
|---|---|---|
| Social | `SocialSamplePhotos`, `SocialImageLoader.samplePhotos()` (`Social/SocialTestSupport.swift`) | `SocialDemo` storage paths (`fake/photo/…`, `fake/avatar/…`, `fake/cover/…`) through the image loader's synchronous renderer |
| Memory | `MemorySamplePhotos` (`Memory/MemoryTestSupport.swift`) | every post rendition of `FixtureMemoryData.scenario` at its own shape, the collage, the tribute poster |
| Capture | `CaptureTestImages`, `CaptureTestRig.usePhotos()` (`Capture/CaptureTestSupport.swift`) | camera preview, the shutter's stills (`FakeCaptureCamera.backStill` / `frontStill`), library thumbnail, group covers, dual images, collage pages, widget renditions and avatars |
| Account | `AccountSamplePhotos` (`Account/AccountTestSupport.swift`) | gives `InMemoryAccountData` people avatars and groups covers, then decodes every avatar, cover and post path into the app's `ImagePipeline` at the pixel buckets the screens draw (snapshots do not wait for `StorageImage` loads) |

The in-app DEBUG demo data (`SocialDemo` / `-SocialFakes`, `FixtureMemoryData` / `-MemoryFixtures`, capture fakes)
keeps its generated colours: the app process cannot read this folder.

**Android:** one shared, test-only Gradle module, `:core:testing` (`android/core/testing`, `app.testing.SamplePhotos`),
added with `testImplementation(project(":core:testing"))` to `:core:ui`, `:feature:account`, `:feature:capture`,
`:feature:social` and `:feature:memory`. The root `android/build.gradle.kts` passes this folder to every unit-test JVM
as `-Dapp.samplePhotos=<path>` and declares it as a task input (changing a photo re-runs the tests); outside Gradle
the helper finds the folder by walking up from the working directory. It serves files, bytes, bitmaps cropped to an
exact size, painters, JPEG files, grid collages, and a Coil `ImageLoader` that answers `SamplePhotos.url(name)` without
a network:

| Module | Where |
|---|---|
| `:core:ui` | `app.ui.snapshots.*SnapshotTest` (`SnapshotTest` helpers `portrait` / `card` / `square` / `story` / `landscape` / `avatar`): every component photo, tile, card, grid, viewer, backdrop and avatar of C-01…C-35, light and dark |
| `:feature:social` | `TestPhotos` (`TestSupport.kt`) behind `LocalPhotoOverride`: posts by media id, avatars by user, the group cover, wall collages; every painter keeps the generated image's intrinsic size (120 × 160 px) |
| `:feature:capture` | `Images` (`Fakes.kt`), `CollagePage`: viewfinder, stills, selfie inset, send-to covers, collage pages, widget renditions, collages and avatars |
| `:feature:memory` | `TestImages` (`SnapshotSupport.kt`) behind `LocalMemoryImages`, cropped to the shape each URL names, keeping the generated images' intrinsic size (w × 120 by h × 120 px) |
| `:feature:account` | `ScreenSnapshotTest`: storage URLs are `SamplePhotos.url(…)`, answered by `SamplePhotos.imageLoader` installed with `SingletonImageLoader.setUnsafe` |

Layouts do not depend on which photo is shown: where a screen sizes an image by its intrinsic size, the painters
report the size of the generated images they replaced (`SamplePhotos.painter(name, w, h, intrinsicWidth,
intrinsicHeight)`) and draw the photo sharp at whatever size they get. One measured fixture depends on the picture:
`android/feature/memory/verification/checklists.py` finds the birthday.tribute player box by colour, so the tribute
poster (`baby-bow-blanket-4x5`, on both platforms) is colourful to its edges and has no pure-white pixels.

Re-record after changing photos: `./gradlew <module>:testDebugUnitTest -Proborazzi.test.verify=false -Proborazzi.test.record=true`
(Android); the iOS snapshots are recorded by CI on every run.

## Photos

| File | Source page | Photographer | Licence | Original size | Orientation (stored size) | What it shows |
|---|---|---|---|---|---|---|
| `friends-coffee-highfive-3x4.jpg` | https://unsplash.com/photos/l_ExpFwwOEg | Toa Heftiba | Unsplash License | 3653×5480 | portrait 3:4 (810×1080) | Four friends on a sunny window seat laughing and high-fiving over mugs of tea |
| `friends-picnic-blanket-3x4.jpg` | https://unsplash.com/photos/tvbxqXI5mmo | Simi Iluyomade | Unsplash License | 2048×3089 | portrait 3:4 (810×1080) | Friends lying head to head on a white picnic blanket, laughing |
| `friends-stairs-laughing-3x4.jpg` | https://unsplash.com/photos/HvZDCuRnSaY | Joel Muniz | Unsplash License | 2912×4368 | portrait 3:4 (810×1080) | A group of friends sitting close together on outdoor stairs, laughing |
| `friends-floor-laughing-3x4.jpg` | https://unsplash.com/photos/nnLMFQ4p1HM | Sarah Noltner | Unsplash License | 4160×6240 | portrait 3:4 (810×1080) | Two friends sitting on a studio floor, leaning together and laughing |
| `dinner-toast-candles-3x4.jpg` | https://unsplash.com/photos/7BpuzmcxlHU | krakenimages | Unsplash License | 5304×7952 | portrait 3:4 (810×1080) | Hands raising red-wine glasses over a candle-lit holiday dinner table |
| `dinner-long-table-3x4.jpg` | https://unsplash.com/photos/KZfUMAgVPCg | Taylor Heery | Unsplash License | 8256×6192 | portrait 3:4 (810×1080) | A big family-style dinner at one long table under ceiling fans |
| `dinner-pizza-cheers-3x4.jpg` | https://unsplash.com/photos/DmO662qvWO8 | Davey Gravy | Unsplash License | 3771×4714 | portrait 3:4 (810×1080) | Two glasses of red wine clinking over pizza and pasta |
| `grandma-newborn-3x4.jpg` | https://unsplash.com/photos/m3ypbJjvXks | Tim Mossholder | Unsplash License | 4682×7023 | portrait 3:4 (810×1080) | A grandmother smiling at the newborn in her arms |
| `grandpa-grandchild-3x4.jpg` | https://unsplash.com/photos/vh8T3QwFPkk | Jeferson Santu | Unsplash License | 4000×6000 | portrait 3:4 (810×1080) | A grandfather in glasses face to face with the toddler he is holding |
| `birthday-cake-candles-3x4.jpg` | https://unsplash.com/photos/d8s13D29QiE | Aneta Pawlik | Unsplash License | 3264×4928 | portrait 3:4 (810×1080) | A lighter reaching the last candles on a frosted birthday cake with berries |
| `dog-beach-run-3x4.jpg` | https://unsplash.com/photos/yihlaRCCvd4 | Oscar Sutton | Unsplash License | 4016×6016 | portrait 3:4 (810×1080) | A happy brown dog running out of the sea at golden hour |
| `coffee-latte-heart-3x4.jpg` | https://unsplash.com/photos/XOhI_kW_TaM | Nathan Dumlao | Unsplash License | 4480×6720 | portrait 3:4 (810×1080) | Top view of a heart latte in a white cup on a bed of coffee beans |
| `hike-meadow-trail-3x4.jpg` | https://unsplash.com/photos/7MrXw_o7Eo4 | Holly Mandarich | Unsplash License | 3456×5184 | portrait 3:4 (810×1080) | Two hikers and a dog on a green mountain trail |
| `hike-mountain-friends-3x4.jpg` | https://unsplash.com/photos/vIluu0IH6Ps | JUSTIN BUISSON | Unsplash License | 3883×5824 | portrait 3:4 (810×1080) | Four friends with backpacks walking a grassy ridge toward snowy peaks |
| `city-night-street-3x4.jpg` | https://unsplash.com/photos/D6Bk1A3-gMA | Patrick Tomasso | Unsplash License | 3648×5472 | portrait 3:4 (810×1080) | An empty, rain-wet city avenue at night with tram tracks and street lights |
| `concert-confetti-3x4.jpg` | https://unsplash.com/photos/3BcNKoySAq0 | Samuel Regan-Asante | Unsplash License | 2689×4032 | portrait 3:4 (810×1080) | A concert crowd under purple stage lights and falling confetti |
| `picnic-spread-3x4.jpg` | https://unsplash.com/photos/it-VGwoQ6XQ | Calvin Shelwell | Unsplash License | 4181×5225 | portrait 3:4 (810×1080) | Top view of a picnic on a white cloth: bread, cheese, fruit, wine glasses |
| `baby-smile-3x4.jpg` | https://unsplash.com/photos/OJOE587CWuE | Christian Bowen | Unsplash License | 4016×6016 | portrait 3:4 (810×1080) | A smiling baby in a grey romper sitting on a fluffy rug |
| `wedding-toast-3x4.jpg` | https://unsplash.com/photos/qa0gEVBTyRY | Alexander Mass | Unsplash License | 4000×6000 | portrait 3:4 (810×1080) | Wedding guests at a long table on a covered porch raising their glasses |
| `snow-forest-walk-3x4.jpg` | https://unsplash.com/photos/_xulc7N0xOo | adrianna geo | Unsplash License | 2160×3240 | portrait 3:4 (810×1080) | Two friends standing in a snowy pine forest |
| `cat-orange-3x4.jpg` | https://unsplash.com/photos/75715CVEJhI | Amber Kipp | Unsplash License | 3961×5546 | portrait 3:4 (810×1080) | A fluffy orange cat lying on a wooden table, looking up |
| `plants-shelf-3x4.jpg` | https://unsplash.com/photos/eg6JOdycgf0 | Tatyana Rubleva | Unsplash License | 3840×5760 | portrait 3:4 (810×1080) | Houseplants on a wooden window shelf |
| `pizza-table-3x4.jpg` | https://unsplash.com/photos/frTrM7Gdkho | Nadya Filatova | Unsplash License | 3744×5616 | portrait 3:4 (810×1080) | Top view of a basil pizza on a wooden table with peppers and a blue cloth |
| `campfire-woods-3x4.jpg` | https://unsplash.com/photos/4FPqmXURTZU | Evan Wise | Unsplash License | 2745×4110 | portrait 3:4 (810×1080) | Friends at a campfire among tents in the woods at dusk |
| `autumn-path-3x4.jpg` | https://unsplash.com/photos/j_enj50EoDY | Dariia Lemesheva | Unsplash License | 3648×5472 | portrait 3:4 (810×1080) | A park path under orange autumn trees |
| `new-parents-3x4.jpg` | https://unsplash.com/photos/WvVyudMd1Es | Kelly Sikkema | Unsplash License | 3712×5568 | portrait 3:4 (810×1080) | New parents holding their sleeping newborn by a window |
| `friends-beach-hug-4x5.jpg` | https://unsplash.com/photos/aMPjULm0XzI | Baylee Gramling | Unsplash License | 4355×6532 | portrait 4:5 (864×1080) | Two friends on the beach at dusk, laughing and pointing at the camera |
| `cake-chocolate-candles-4x5.jpg` | https://unsplash.com/photos/qSPxjNn7Uy8 | Duncan Kidd | Unsplash License | 3446×5176 | portrait 4:5 (864×1080) | A dark chocolate cake with lit candles on a black background |
| `kitten-yawn-4x5.jpg` | https://unsplash.com/photos/7AIDE8PrvA0 | Loan | Unsplash License | 2955×3694 | portrait 4:5 (864×1080) | A tabby kitten yawning on a wooden floor |
| `ice-cream-cone-4x5.jpg` | https://unsplash.com/photos/TLD6iCOlyb0 | ian dooley | Unsplash License | 3456×5184 | portrait 4:5 (864×1080) | A hand holding a strawberry ice-cream cone against a yellow wall |
| `baby-bow-blanket-4x5.jpg` | https://unsplash.com/photos/uFCkcE6GI40 | Christian Bowen | Unsplash License | 3264×4928 | portrait 4:5 (864×1080) | A baby with a big yellow bow lying on a quilt outdoors, smiling |
| `grandparent-walk-4x5.jpg` | https://unsplash.com/photos/snDUMdYF7o8 | Janosch Lino | Unsplash License | 3264×4928 | portrait 4:5 (864×1080) | A grandparent and grandchild walking arm in arm down a park path |
| `sunset-sea-9x16.jpg` | https://unsplash.com/photos/64LL2fP9uXM | Jordan Steranka | Unsplash License | 3648×5472 | portrait 9:16 (608×1080) | A pink and blue sunset sky over the sea |
| `sunset-lake-9x16.jpg` | https://unsplash.com/photos/lsoogGC_5dg | Dave Hoefler | Unsplash License | 4480×6272 | portrait 9:16 (608×1080) | A small wooded island reflected in a calm lake at sunset |
| `beach-sunset-wade-9x16.jpg` | https://unsplash.com/photos/ZXI46eRJAx4 | Adam Thomas | Unsplash License | 4000×6000 | portrait 9:16 (608×1080) | Friends wading in the shallows toward a low sun |
| `cat-window-9x16.jpg` | https://unsplash.com/photos/UxWy8Un2Mjc | Jonathan Ikemura | Unsplash License | 4000×6000 | portrait 9:16 (608×1080) | A long-haired cat sitting in a sunlit window |
| `autumn-bike-9x16.jpg` | https://unsplash.com/photos/xu2pJBFTW-M | Jorgen Hendriksen | Unsplash License | 3923×5885 | portrait 9:16 (608×1080) | Someone cycling down a leaf-covered forest path in autumn |
| `selfie-two-friends-1x1.jpg` | https://unsplash.com/photos/UhFYNKaObYY | Vitaly Gariev | Unsplash License | 3840×2160 | square 1:1 (1080×1080) | Two friends taking a selfie at a cafe table, coffee and croissant in front |
| `succulents-1x1.jpg` | https://unsplash.com/photos/ncQ2sguVlgo | Annie Spratt | Unsplash License | 2090×3000 | square 1:1 (1080×1080) | Top view of small succulents in clay pots on white |
| `snow-friends-beanies-1x1.jpg` | https://unsplash.com/photos/7Rh4X6sP3B8 | Genessa Panainte | Unsplash License | 6016×4016 | square 1:1 (1080×1080) | Two friends in knit beanies and blankets in the snow |
| `kids-bubbles-1x1.jpg` | https://unsplash.com/photos/wtxcaDIdOCM | Leo Rivas | Unsplash License | 3744×2487 | square 1:1 (1080×1080) | A little girl in a green coat reaching for soap bubbles in a park |
| `coffee-cup-top-1x1.jpg` | https://unsplash.com/photos/nBJHO6wmRWw | Nathan Dumlao | Unsplash License | 3087×4631 | square 1:1 (1080×1080) | Top view of a cup of black coffee on a wooden table |
| `family-dinner-4x3.jpg` | https://unsplash.com/photos/wYOPqmtDD0w | Pablo Merchán Montes | Unsplash License | 5472×3648 | landscape 4:3 (1080×810) | A family raising their glasses at a warm restaurant table |
| `road-trip-window-3x2.jpg` | https://unsplash.com/photos/ocJ2YBsjAf4 | Maria Ivanova | Unsplash License | 6240×4160 | landscape 3:2 (1080×720) | Mountains framed by a car window on a road trip |
| `beach-friends-run-4x3.jpg` | https://unsplash.com/photos/AvnXCFX25GA | Vidar Nordli-Mathisen | Unsplash License | 2880×1711 | landscape 4:3 (1080×810) | A row of friends running into clear sea water |
| `grandma-hug-4x3.jpg` | https://unsplash.com/photos/L4nwL3195U0 | Ekaterina Shakharova | Unsplash License | 3872×2592 | landscape 4:3 (1080×810) | A grandmother laughing as a child hugs her |
| `movie-night-couch-4x3.jpg` | https://unsplash.com/photos/gg7VozgvWqk | Vitaly Gariev | Unsplash License | 3840×2160 | landscape 4:3 (1080×810) | Two friends on a couch with popcorn, watching a movie |
| `food-plates-4x3.jpg` | https://unsplash.com/photos/Q_Moi2xjieU | Stefan Vladimirov | Unsplash License | 5518×3679 | landscape 4:3 (1080×810) | Top view of a shared table of plates and salads |
| `campfire-friends-3x2.jpg` | https://unsplash.com/photos/fth3mtAWTLw | Vitaly Gariev | Unsplash License | 3800×2138 | landscape 3:2 (1080×720) | Friends laughing around a campfire at night |
| `avatar-01.jpg` | https://unsplash.com/photos/Ll9YOG20UFI | Nolan Manning | Unsplash License | 2832×3540 | square 1:1 (256×256) | Head-and-shoulders portrait: young woman with curly hair, smiling |
| `avatar-02.jpg` | https://unsplash.com/photos/iFgRcqHznqg | Joseph Gonzalez | Unsplash License | 3569×5354 | square 1:1 (256×256) | Head-and-shoulders portrait: man in a white T-shirt, smiling |
| `avatar-03.jpg` | https://unsplash.com/photos/t9tDSXN2U2E | Daniel Lara | Unsplash License | 3770×4685 | square 1:1 (256×256) | Head-and-shoulders portrait: older woman with white hair, smiling |
| `avatar-04.jpg` | https://unsplash.com/photos/n4KewLKFOZw | Imansyah Muhamad Putera | Unsplash License | 3456×3456 | square 1:1 (256×256) | Head-and-shoulders portrait: teenage boy |
| `avatar-05.jpg` | https://unsplash.com/photos/n45Wbm8gpm0 | Gabriel Ogulu | Unsplash License | 3530×5295 | square 1:1 (256×256) | Head-and-shoulders portrait: woman in glasses, laughing |
| `avatar-06.jpg` | https://unsplash.com/photos/0YyO9TlvJKo | Andrew Kayani | Unsplash License | 4000×6000 | square 1:1 (256×256) | Head-and-shoulders portrait: man in a green polo, smiling |
| `avatar-07.jpg` | https://unsplash.com/photos/Ov6eGr-dSxA | Tom Morbey | Unsplash License | 2121×2755 | square 1:1 (256×256) | Head-and-shoulders portrait: older man with a white beard |
| `avatar-08.jpg` | https://unsplash.com/photos/IF9TK5Uy-KI | Jake Nackos | Unsplash License | 3974×5000 | square 1:1 (256×256) | Head-and-shoulders portrait: woman with her hair up, smiling |
| `avatar-09.jpg` | https://unsplash.com/photos/y3kC_7Qhmjk | nrd | Unsplash License | 3456×4608 | square 1:1 (256×256) | Head-and-shoulders portrait: young person laughing |
| `avatar-10.jpg` | https://unsplash.com/photos/62GTOD-oY0w | Freddy Bwira Mishiki | Unsplash License | 3744×5616 | square 1:1 (256×256) | Head-and-shoulders portrait: young woman laughing against a blue wall |
