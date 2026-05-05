package com.gindausd.max.services

import android.content.Context
import android.provider.ContactsContract

class ContactsService {

    data class Contact(val displayName: String, val phoneNumber: String)

    fun lookupByName(context: Context, name: String): List<Contact> {
        val results = mutableListOf<Contact>()
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
        )
        val selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?"
        val selectionArgs = arrayOf("%$name%")

        try {
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
            )?.use { cursor ->
                val seenNames = mutableSetOf<String>()
                while (cursor.moveToNext() && results.size < 5) {
                    val displayName = cursor.getString(0) ?: continue
                    val number = cursor.getString(1)?.filter { it.isDigit() || it == '+' } ?: continue
                    if (seenNames.add(displayName)) {
                        results.add(Contact(displayName, number))
                    }
                }
            }
        } catch (e: SecurityException) {
            // READ_CONTACTS permission not granted
        }

        return results
    }

    fun findBestMatch(context: Context, name: String): Contact? =
        lookupByName(context, name).firstOrNull()

    companion object {
        @Volatile private var INSTANCE: ContactsService? = null
        fun getInstance(): ContactsService =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: ContactsService().also { INSTANCE = it }
            }
    }
}
