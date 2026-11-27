package com.ofilabs.jelilabel

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class JeliLabelWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.jelilabel_widget).apply {
                val adaCatatan = widgetData.getBoolean("ada_catatan", false)
                val diperbarui = widgetData.getString("diperbarui", "") ?: ""
                setTextViewText(R.id.widget_diperbarui, diperbarui)

                if (adaCatatan) {
                    setViewVisibility(R.id.widget_isi_catatan, View.VISIBLE)
                    setViewVisibility(R.id.widget_kosong, View.GONE)
                    setViewVisibility(R.id.widget_tombol_barcode, View.VISIBLE)

                    setTextViewText(R.id.widget_teks_sisa, widgetData.getString("teks_sisa", "") ?: "")
                    setTextViewText(R.id.widget_label_status, widgetData.getString("label_status", "") ?: "")

                    val persen = (widgetData.all["persen_terpakai"] as? Number)?.toInt()?.coerceIn(0, 100) ?: 0
                    when (widgetData.getString("kode_status", "aman")) {
                        "hampir_batas" -> {
                            setInt(R.id.widget_label_status, "setBackgroundResource", R.drawable.widget_chip_waspada)
                            setTextColor(
                                R.id.widget_label_status,
                                ContextCompat.getColor(context, R.color.widget_waspada_chip),
                            )
                            setViewVisibility(R.id.widget_bilah_aman, View.GONE)
                            setViewVisibility(R.id.widget_bilah_waspada, View.VISIBLE)
                            setViewVisibility(R.id.widget_bilah_tinggi, View.GONE)
                            setProgressBar(R.id.widget_bilah_waspada, 100, persen, false)
                        }
                        "lewat_batas" -> {
                            setInt(R.id.widget_label_status, "setBackgroundResource", R.drawable.widget_chip_tinggi)
                            setTextColor(
                                R.id.widget_label_status,
                                ContextCompat.getColor(context, R.color.widget_tinggi_chip),
                            )
                            setViewVisibility(R.id.widget_bilah_aman, View.GONE)
                            setViewVisibility(R.id.widget_bilah_waspada, View.GONE)
                            setViewVisibility(R.id.widget_bilah_tinggi, View.VISIBLE)
                            setProgressBar(R.id.widget_bilah_tinggi, 100, persen, false)
                        }
                        else -> {
                            setInt(R.id.widget_label_status, "setBackgroundResource", R.drawable.widget_chip_aman)
                            setTextColor(
                                R.id.widget_label_status,
                                ContextCompat.getColor(context, R.color.widget_aman_chip),
                            )
                            setViewVisibility(R.id.widget_bilah_aman, View.VISIBLE)
                            setViewVisibility(R.id.widget_bilah_waspada, View.GONE)
                            setViewVisibility(R.id.widget_bilah_tinggi, View.GONE)
                            setProgressBar(R.id.widget_bilah_aman, 100, persen, false)
                        }
                    }
                } else {
                    setViewVisibility(R.id.widget_isi_catatan, View.GONE)
                    setViewVisibility(R.id.widget_kosong, View.VISIBLE)
                    setViewVisibility(R.id.widget_tombol_barcode, View.GONE)
                }

                setOnClickPendingIntent(
                    R.id.widget_akar,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("jelilabel://beranda"),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.widget_tombol_pindai,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("jelilabel://pindai"),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.widget_tombol_barcode,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("jelilabel://barcode"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
