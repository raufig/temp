package com.petalgemini

import android.app.Application
import com.petalgemini.db.ConversationDatabase

/**
 * Application class — inicializa la base de datos al arrancar.
 */
class PetalGeminiApp : Application() {

    lateinit var database: ConversationDatabase
        private set

    override fun onCreate() {
        super.onCreate()
        database = ConversationDatabase.getInstance(this)
    }
}
