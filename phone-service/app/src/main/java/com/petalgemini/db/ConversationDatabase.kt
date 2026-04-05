package com.petalgemini.db

import android.content.Context
import androidx.room.*

/**
 * Módulo 6 — Historial y contexto
 *
 * Room Database que guarda los últimos 10 intercambios con timestamp.
 * El servicio incluye los últimos 3 en cada llamada a Gemini para dar contexto.
 */

@Entity(tableName = "conversations")
data class ConversationEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    @ColumnInfo(name = "query") val query: String,
    @ColumnInfo(name = "response") val response: String,
    @ColumnInfo(name = "timestamp") val timestamp: Long
)

@Dao
interface ConversationDao {

    @Query("SELECT * FROM conversations ORDER BY timestamp DESC LIMIT :limit")
    suspend fun getRecent(limit: Int = 10): List<ConversationEntity>

    @Query("SELECT * FROM conversations ORDER BY timestamp DESC LIMIT 3")
    suspend fun getLastThree(): List<ConversationEntity>

    @Insert
    suspend fun insert(entry: ConversationEntity)

    /**
     * Mantiene solo los últimos 10 registros, borra los más antiguos.
     */
    @Query("DELETE FROM conversations WHERE id NOT IN (SELECT id FROM conversations ORDER BY timestamp DESC LIMIT 10)")
    suspend fun pruneOld()

    @Query("DELETE FROM conversations")
    suspend fun clearAll()

    @Query("SELECT COUNT(*) FROM conversations")
    suspend fun count(): Int
}

@Database(entities = [ConversationEntity::class], version = 1, exportSchema = false)
abstract class ConversationDatabase : RoomDatabase() {
    abstract fun conversationDao(): ConversationDao

    companion object {
        @Volatile
        private var INSTANCE: ConversationDatabase? = null

        fun getInstance(context: Context): ConversationDatabase {
            return INSTANCE ?: synchronized(this) {
                Room.databaseBuilder(
                    context.applicationContext,
                    ConversationDatabase::class.java,
                    "petalgemini_conversations"
                ).build().also { INSTANCE = it }
            }
        }
    }
}
