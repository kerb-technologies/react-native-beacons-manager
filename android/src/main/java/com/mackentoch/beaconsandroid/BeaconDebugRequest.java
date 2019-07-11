package com.mackentoch.beaconsandroid;

import android.os.AsyncTask;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.DataOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.ProtocolException;
import java.net.URL;

public class BeaconDebugRequest extends AsyncTask<JSONObject, Void, Void> {
    protected void onPreExecute() {
        //display progress dialog.

    }

    protected Void doInBackground(JSONObject... params) {
        HttpURLConnection con = null;
        JSONObject payload = params[0];
        String debugApi = null;
        try {
            debugApi = (String) params[1].get("debugApi");
        } catch (JSONException e) {
            e.printStackTrace();
        }

        if(debugApi != null) {
            try {
                URL url = new URL(debugApi);
                con = (HttpURLConnection) url.openConnection();
                con.setRequestMethod("POST");
                con.setRequestProperty("Content-Type", "application/json");
                con.setDoOutput(true);
                con.connect();
                DataOutputStream wr = new DataOutputStream(con.getOutputStream());
                wr.writeBytes(payload != null ? payload.toString() : "");
                wr.flush();
                wr.close();
                int HttpResult = con.getResponseCode();
                Log.d("BeaconsAndroidModule", "BeaconDebugRequest Response Code " + HttpResult);
            } catch (ProtocolException e) {
                e.printStackTrace();
            } catch (MalformedURLException e) {
                e.printStackTrace();
            } catch (IOException e) {
                e.printStackTrace();
            } finally {
                if (con != null)
                    con.disconnect();
            }
        }

        return null;
    }


    protected void onPostExecute(Void result) {
        // dismiss progress dialog and update ui
    }

}
