package app.data.integration

import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.Album
import app.data.model.AlbumItem
import app.data.model.Block
import app.data.model.ChatTyping
import app.data.model.Collage
import app.data.model.DailyInvitation
import app.data.model.Device
import app.data.model.Entitlement
import app.data.model.Group
import app.data.model.GroupInvite
import app.data.model.GroupMember
import app.data.model.Media
import app.data.model.Message
import app.data.model.MessageReaction
import app.data.model.NotificationSettings
import app.data.model.Post
import app.data.model.PostTag
import app.data.model.Profile
import app.data.model.ProfilePrivate
import app.data.model.PublicAppConfigRow
import app.data.model.Reaction
import app.data.model.SelfieReaction
import app.data.model.Tribute
import app.data.model.TributeContribution
import app.data.model.TributeRequest
import app.data.model.WeeklyRecap
import app.data.model.YearStory
import app.data.remote.Rpc
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.SerialKind
import kotlinx.serialization.descriptors.elementNames
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The models and RPC specs against the live database (PostgREST's OpenAPI description): every
 * table model has exactly the table's columns with the same nullability and enum values, and every
 * RPC the app calls has exactly the parameters (and required ones) the function declares.
 */
@RunWith(AndroidJUnit4::class)
class SchemaConformanceIntegrationTest {
    private lateinit var openApi: JsonObject
    private lateinit var clientOpenApi: JsonObject

    @Before fun setUp() {
        LocalStack.assumeReachable()
        runBlocking {
            Admin().use { admin ->
                openApi = admin.openApi()
                val account = admin.createUser("Schema ${uniqueTag()}")
                try {
                    clientOpenApi = admin.openApi(bearer = admin.accessToken(account), apiKey = LocalStack.anonKey)
                } finally {
                    admin.deleteUser(account.id)
                }
            }
        }
    }

    private val models: Map<String, SerialDescriptor> = mapOf(
        "profiles" to Profile.serializer().descriptor,
        "profile_private" to ProfilePrivate.serializer().descriptor,
        "groups" to Group.serializer().descriptor,
        "group_members" to GroupMember.serializer().descriptor,
        "group_invites" to GroupInvite.serializer().descriptor,
        "blocks" to Block.serializer().descriptor,
        "media" to Media.serializer().descriptor,
        "posts" to Post.serializer().descriptor,
        "messages" to Message.serializer().descriptor,
        "reactions" to Reaction.serializer().descriptor,
        "message_reactions" to MessageReaction.serializer().descriptor,
        "chat_typing" to ChatTyping.serializer().descriptor,
        "selfie_reactions" to SelfieReaction.serializer().descriptor,
        "post_tags" to PostTag.serializer().descriptor,
        "daily_invitations" to DailyInvitation.serializer().descriptor,
        "collages" to Collage.serializer().descriptor,
        "weekly_recaps" to WeeklyRecap.serializer().descriptor,
        "albums" to Album.serializer().descriptor,
        "album_items" to AlbumItem.serializer().descriptor,
        "tribute_requests" to TributeRequest.serializer().descriptor,
        "tribute_contributions" to TributeContribution.serializer().descriptor,
        "tributes" to Tribute.serializer().descriptor,
        "year_stories" to YearStory.serializer().descriptor,
        "devices" to Device.serializer().descriptor,
        "notification_settings" to NotificationSettings.serializer().descriptor,
        "entitlements" to Entitlement.serializer().descriptor,
        "public_app_config" to PublicAppConfigRow.serializer().descriptor,
    )

    /** Not null in the database but optional in the model: rows the device makes before the server has set them. */
    private val nullableOnDevice = setOf(
        // Set by the posts_set_visible_at trigger (migration 0050); Post.visibleAt falls back to revealed_at / created_at.
        "posts.visible_at",
    )

    @Test fun everyTableModelMirrorsTheLiveTable() {
        val definitions = openApi["definitions"]!!.jsonObject
        val problems = mutableListOf<String>()
        for ((table, descriptor) in models) {
            val definition = definitions[table]?.jsonObject
            if (definition == null) {
                problems += "$table: not in the database"
                continue
            }
            val columns = definition["properties"]!!.jsonObject
            val required = definition["required"]?.jsonArray?.map { it.jsonPrimitive.content }?.toSet()
            val fields = descriptor.elementNames.toList()
            if (fields != columns.keys.toList()) problems += "$table: model ${fields} vs table ${columns.keys.toList()}"
            for (i in 0 until descriptor.elementsCount) {
                val name = descriptor.getElementName(i)
                val column = columns[name]?.jsonObject ?: continue
                val element = descriptor.getElementDescriptor(i)
                if (required != null) {
                    val notNull = name in required
                    if (notNull == element.isNullable && "$table.$name" !in nullableOnDevice) problems += "$table.$name: model nullable=${element.isNullable}, column not null=$notNull"
                }
                val dbEnum = column["enum"]?.jsonArray?.map { it.jsonPrimitive.content }
                if (dbEnum != null) {
                    if (element.kind != SerialKind.ENUM) problems += "$table.$name: column is an enum $dbEnum, model is ${element.kind}"
                    else if (element.elementNames.toList() != dbEnum) problems += "$table.$name: enum ${element.elementNames.toList()} vs $dbEnum"
                }
            }
        }
        assertTrue(problems.joinToString("\n"), problems.isEmpty())
    }

    @Test fun everyRpcSpecMatchesTheLiveFunction() {
        val paths = openApi["paths"]!!.jsonObject
        val problems = mutableListOf<String>()
        for (rpc in Rpc.entries) {
            val post = paths["/rpc/${rpc.function}"]?.jsonObject?.get("post")?.jsonObject
            if (post == null) {
                problems += "${rpc.function}: not exposed"
                continue
            }
            val body = post["parameters"]?.jsonArray?.map { it.jsonObject }?.firstOrNull { it["in"]?.jsonPrimitive?.content == "body" }
            val schema = body?.get("schema")?.jsonObject
            val params = schema?.get("properties")?.jsonObject?.keys.orEmpty()
            val required = schema?.get("required")?.jsonArray?.map { it.jsonPrimitive.content }?.toSet().orEmpty()
            if (params != rpc.parameters) problems += "${rpc.function}: spec ${rpc.parameters.sorted()} vs db ${params.sorted()}"
            if (required != rpc.required) problems += "${rpc.function}: required ${rpc.required.sorted()} vs db ${required.sorted()}"
        }
        // What a signed-in client may execute must be exactly what the app has specs for.
        val clientCallable = clientOpenApi["paths"]!!.jsonObject.keys.filter { it.startsWith("/rpc/") }.map { it.removePrefix("/rpc/") }.toSet()
        val known = Rpc.entries.map { it.function }.toSet()
        if (clientCallable - known != emptySet<String>()) problems += "client-callable functions without a spec: ${(clientCallable - known).sorted()}"
        if (known - clientCallable != emptySet<String>()) problems += "specs for functions a client cannot call: ${(known - clientCallable).sorted()}"
        assertTrue(problems.joinToString("\n"), problems.isEmpty())
    }
}
