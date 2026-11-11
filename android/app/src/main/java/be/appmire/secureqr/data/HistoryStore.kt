package be.appmire.secureqr.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.builtins.ListSerializer

private val Context.historyDataStore: DataStore<Preferences> by preferencesDataStore(name = "history")

/** On-device scan history, newest first. Nothing here ever leaves the phone. */
class HistoryStore(context: Context) {
    private val store = context.applicationContext.historyDataStore

    val entries: Flow<List<HistoryEntry>> = store.data.map { decode(it[KEY]) }

    suspend fun add(entry: HistoryEntry) = update { HistoryLog.add(it, entry) }

    suspend fun setLevel(id: String, level: String, now: Long) = update { HistoryLog.setLevel(it, id, level, now) }

    suspend fun delete(id: String) = update { HistoryLog.delete(it, id) }

    suspend fun clear() {
        store.edit { it.remove(KEY) }
    }

    private suspend fun update(transform: (List<HistoryEntry>) -> List<HistoryEntry>) {
        store.edit { prefs ->
            prefs[KEY] = ApiJson.encodeToString(SERIALIZER, transform(decode(prefs[KEY])))
        }
    }

    private fun decode(json: String?): List<HistoryEntry> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            ApiJson.decodeFromString(SERIALIZER, json)
        } catch (e: Exception) {
            emptyList()
        }
    }

    private companion object {
        val KEY = stringPreferencesKey("entries")
        val SERIALIZER = ListSerializer(HistoryEntry.serializer())
    }
}
