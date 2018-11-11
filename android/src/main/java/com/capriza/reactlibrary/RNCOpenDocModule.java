
package com.capriza.reactlibrary;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.support.v4.content.FileProvider;
import android.util.Log;
import android.webkit.MimeTypeMap;

import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeArray;

import java.io.File;
import java.net.HttpURLConnection;

public class RNCOpenDocModule extends ReactContextBaseJavaModule implements ActivityEventListener {
  private static final String LOG_TAG = "RNCOpenDoc";
  private static final int PICK_REQUEST_CODE = 1978;

  private static class Fields {
    private static final String FILE_NAME = "fileName";
    private static final String TYPE = "type";
  }

  private Callback callback;

  private final ReactApplicationContext reactContext;

  public RNCOpenDocModule(ReactApplicationContext reactContext) {
    super(reactContext);
    reactContext.addActivityEventListener(this);
    this.reactContext = reactContext;
  }

  @Override
  public String getName() {
    return "RNCOpenDoc";
  }

  private String getMimeType(String filePath) {
    String ext = "";
    int nameEndIndex = filePath.lastIndexOf('.');
    if (nameEndIndex > 0) {
      ext = filePath.substring(nameEndIndex + 1);
    }
    Log.d(LOG_TAG, ext);
    MimeTypeMap mime = MimeTypeMap.getSingleton();
    String type = mime.getMimeTypeFromExtension(ext.toLowerCase());
    if (type == null) {
      type = HttpURLConnection.guessContentTypeFromName(filePath);
    }

    if (type == null) {
      type = "application/" + ext;
    }
    return type;
  }

  @ReactMethod
  public void open(String path) {
    if (path.startsWith("file://")) {
      path = path.replace("file://", "");
    }

    File file = new File(path);
    if (!file.exists()) {
      Log.e(LOG_TAG, "File does not exist");
      return;
    }

    try {
      Uri uri = FileProvider.getUriForFile(reactContext.getApplicationContext(),reactContext.getApplicationContext().getPackageName() + ".provider", file);

      String type = this.getMimeType(uri.toString());

      Intent intent = new Intent(Intent.ACTION_VIEW, uri);

      if (type != null && uri != null) {
        intent.setDataAndType(uri, type);
      } else if (type != null) {
        intent.setType(type);
      }

      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

      getReactApplicationContext().startActivity(intent);
    } catch(ActivityNotFoundException ex) {
      Log.e(LOG_TAG, "can't open document", ex);
    }
  }

  @ReactMethod
  public void share(String path) {
    if (path.startsWith("file://")) {
      path = path.replace("file://", "");
    }

    File file = new File(path);
    if (!file.exists()) {
      Log.e(LOG_TAG, "File does not exist");
      return;
    }

    try {
      Uri uri = FileProvider.getUriForFile(reactContext.getApplicationContext(),reactContext.getApplicationContext().getPackageName() + ".provider", file);

      String type = this.getMimeType(uri.toString());

      Intent shareIntent = new Intent();
      shareIntent.setAction(Intent.ACTION_SEND);
      shareIntent.putExtra(Intent.EXTRA_STREAM, uri);
      shareIntent.setType(type);
      shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

      Intent i = Intent.createChooser(shareIntent, "Share");
      i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

      getReactApplicationContext().startActivity(i);
    } catch(ActivityNotFoundException ex) {
      Log.e(LOG_TAG, "can't share document", ex);
    }
  }

  @ReactMethod
  public void pick(ReadableMap args, Callback callback) {
    Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);

    intent.addCategory(Intent.CATEGORY_OPENABLE);
    intent.setType("*/*");

    if (args != null && !args.isNull("fileTypes")) {
      intent.putExtra(Intent.EXTRA_MIME_TYPES, args.getArray("fileTypes").toArrayList().toArray(new String[0]));
    }

    this.callback = callback;

    getReactApplicationContext().startActivityForResult(intent, PICK_REQUEST_CODE, Bundle.EMPTY);
  }

  @Override
  public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {
    onActivityResult(requestCode, resultCode, data);
  }

  @Override
  public void onNewIntent(Intent intent) {

  }

  private void onActivityResult(int requestCode, int resultCode, Intent data) {
    if (requestCode != PICK_REQUEST_CODE)
      return;

    if (resultCode != Activity.RESULT_OK) {
      callback.invoke("Bad result code: " + resultCode, null);
      return;
    }

    if (data == null) {
      callback.invoke("No data", null);
      return;
    }

    try {
      Uri uri = data.getData();
      final WritableNativeArray res = new WritableNativeArray();
      res.pushMap(toMapWithMetadata(uri));
      callback.invoke(null, res);
    } catch (Exception e) {
      Log.e(LOG_TAG, "Failed to read", e);
      callback.invoke(e.getMessage(), null);
    }
  }

  private WritableMap toMapWithMetadata(Uri uri) {
    WritableMap map;
    if(uri.toString().startsWith("/")) {
      map = metaDataFromFile(new File(uri.toString()));
    } else {
      map = metaDataFromContentResolver(uri);
    }

    map.putString("uri", uri.toString());

    return map;
  }

  private WritableMap metaDataFromFile(File file) {
    WritableMap map = Arguments.createMap();

    if(!file.exists())
      return map;

    map.putString(Fields.FILE_NAME, file.getName());
    map.putString(Fields.TYPE, mimeTypeFromName(file.getAbsolutePath()));

    return map;
  }

  private WritableMap metaDataFromContentResolver(Uri uri) {
    WritableMap map = Arguments.createMap();

    ContentResolver contentResolver = getReactApplicationContext().getContentResolver();

    map.putString(Fields.TYPE, contentResolver.getType(uri));

    Cursor cursor = contentResolver.query(uri, null, null, null, null, null);

    try {
      if (cursor != null && cursor.moveToFirst()) {
        map.putString(Fields.FILE_NAME, cursor.getString(cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)));
      }
    } finally {
      if (cursor != null) {
        cursor.close();
      }
    }

    return map;
  }

  private static String mimeTypeFromName(String absolutePath) {
    String extension = MimeTypeMap.getFileExtensionFromUrl(absolutePath);
    if (extension != null) {
      return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
    } else {
      return null;
    }
  }
}