package app.data

import android.content.Context
import app.data.auth.EncryptedSessionManager
import app.data.auth.KeystoreSessionCipher
import app.data.glue.GlueBridges
import app.data.glue.SessionGlue
import app.data.media.MediaStorage
import app.data.media.SignedUrlCache
import app.data.media.upload.PostRemote
import app.data.media.upload.PostUploader
import app.data.media.upload.UploadQueue
import app.data.media.upload.UploadStore
import app.data.model.NewMedia
import app.data.model.Post
import app.data.offline.Connectivity
import app.data.offline.OfflineCache
import app.data.realtime.GroupRealtime
import app.data.realtime.ReconnectPolicy
import app.data.realtime.SupabaseRealtimeChannels
import app.data.remote.Api
import app.data.remote.Rpc
import app.data.repo.AlbumRepository
import app.data.repo.AppConfigRepository
import app.data.repo.AuthRepository
import app.data.repo.BirthdayRepository
import app.data.repo.BrowseRepository
import app.data.repo.ChatRepository
import app.data.repo.DeviceRepository
import app.data.repo.EntitlementRepository
import app.data.repo.GroupRepository
import app.data.repo.InvitationRepository
import app.data.repo.PostOptions
import app.data.repo.PostRepository
import app.data.repo.ProfileRepository
import app.data.repo.ReactionRepository
import app.data.repo.RecapRepository
import app.data.repo.SafetyRepository
import app.data.repo.SettingsRepository
import app.data.repo.TagRepository
import app.data.repo.YearStoryRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import java.io.File
import java.time.Clock

/** Where the data layer keeps its files, and client knobs. */
data class DataOptions(
    val client: ClientOptions,
    /** The offline page cache (per user, deleted on sign-out). */
    val cacheDir: File,
    /** Upload drafts and their file copies. */
    val uploadsDir: File,
    val reconnect: ReconnectPolicy = ReconnectPolicy(),
    val clock: Clock = Clock.systemUTC(),
) {
    companion object {
        /** The app's: encrypted session under `noBackupFilesDir` (tokens and private photos are per-device). */
        fun default(context: Context): DataOptions {
            val dir = File(context.noBackupFilesDir, "data")
            return DataOptions(
                client = ClientOptions(sessionManager = EncryptedSessionManager(File(dir, "session.bin"), KeystoreSessionCipher())),
                cacheDir = File(dir, "offline"),
                uploadsDir = File(dir, "uploads"),
            )
        }
    }
}

/** Account deletion (docs/API.md §6.3): everything you own is deleted, then the session is dropped. */
class AccountRepository(private val api: Api, private val auth: AuthRepository) {
    suspend fun deleteAccount() {
        api.rpcUnit(Rpc.DeleteAccount)
        auth.clearLocalSession()
    }
}

/**
 * The data layer: one Supabase client and every repository built on it. Screens get it from
 * [DataGraph.get]; the app creates it once with [install] (which also starts the [SessionGlue]).
 */
class DataGraph(context: Context, val config: SupabaseConfig, val options: DataOptions) {
    private val appContext = context.applicationContext
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    val client: SupabaseClient = SupabaseSetup.createClient(config, options.client)
    val api = Api(client)
    private val clock = options.clock

    val storage = MediaStorage(client)
    val signedUrls = SignedUrlCache(storage, clock)
    val cache = OfflineCache(options.cacheDir, clock)
    val connectivity by lazy { Connectivity(appContext) }

    val auth = AuthRepository(api, scope)
    val profiles = ProfileRepository(api, storage)
    val groups = GroupRepository(api, storage, cache, clock)
    val posts = PostRepository(api, cache, clock)
    val chat = ChatRepository(api, storage, cache, clock)
    val reactions = ReactionRepository(api)
    val tags = TagRepository(api)
    val browse = BrowseRepository(api, cache, clock)
    val recaps = RecapRepository(api, cache, clock)
    val albums = AlbumRepository(api, cache, clock)
    val yearStories = YearStoryRepository(api)
    val invitations = InvitationRepository(api, clock)
    val birthdays = BirthdayRepository(api, profiles, clock)
    val safety = SafetyRepository(api)
    val settings = SettingsRepository(api)
    val devices = DeviceRepository(api)
    val entitlements = EntitlementRepository(api, clock)
    val appConfig = AppConfigRepository(api)
    val account = AccountRepository(api, auth)

    val realtime = GroupRealtime(SupabaseRealtimeChannels(client, scope), scope, options.reconnect)

    val uploadStore = UploadStore(options.uploadsDir)
    val uploader = PostUploader(RepositoryPostRemote(storage, posts), uploadStore)
    val uploads = UploadQueue(appContext, uploadStore) { auth.currentUserId }

    @Volatile private var glue: SessionGlue? = null

    /** Waits until the stored session has been loaded (and refreshed if needed). */
    suspend fun awaitSessionLoaded() = client.auth.awaitInitialization()

    /** Starts the session glue once (push token, billing identity, widgets, cache upkeep). */
    @Synchronized
    fun startGlue(bridges: GlueBridges = GlueBridges.default(appContext)): SessionGlue =
        glue ?: SessionGlue(auth, groups, devices, settings, realtime, cache, signedUrls, bridges, scope, uploads::discardAll).also {
            it.start()
            glue = it
        }

    /** Stops everything (tests; the app's graph lives as long as the process). */
    suspend fun close() {
        glue?.stop()
        runCatching { client.close() }
        scope.cancel()
    }

    companion object {
        @Volatile private var instance: DataGraph? = null

        /** The process-wide graph; null while `config/app.json` has no Supabase URL / key. */
        fun get(context: Context): DataGraph? = instance ?: synchronized(this) {
            instance ?: SupabaseConfig.fromBuildConfig()?.let { DataGraph(context, it, DataOptions.default(context)) }?.also { instance = it }
        }

        /** From `Application.onCreate`: creates the graph and starts the glue. */
        fun install(context: Context): DataGraph? = get(context)?.also { it.startGlue() }

        /** Tests: use [graph] as the process-wide instance (null resets). */
        fun override(graph: DataGraph?) = synchronized(this) { instance = graph }
    }
}

/** [PostRemote] over storage-kt and [PostRepository]. */
class RepositoryPostRemote(private val storage: MediaStorage, private val posts: PostRepository) : PostRemote {
    override suspend fun upload(path: String, file: File, contentType: String, onProgress: (Long, Long) -> Unit) =
        storage.upload(path, file, contentType, onProgress)

    override suspend fun insertMedia(media: NewMedia) = posts.insertMedia(media)

    override suspend fun createPost(mediaId: String, groupIds: List<String>, options: PostOptions): List<Post> =
        posts.createPost(mediaId, groupIds, options)

    override suspend fun postsOfMedia(mediaId: String): List<Post> = posts.postsOfMedia(mediaId)
}
