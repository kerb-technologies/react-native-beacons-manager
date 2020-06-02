package com.mackentoch.beaconsandroid;

import android.os.AsyncTask;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.DataOutputStream;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.ProtocolException;
import java.net.URL;

public class BeaconRequest extends AsyncTask<JSONObject, Void, Void> {
    protected void onPreExecute() {
        //display progress dialog.

    }

    private static boolean stringNotEmpty(String str) {
        return str != null && !str.trim().isEmpty();
    }

    protected Void doInBackground(JSONObject... params) {
        HttpURLConnection con = null;
        JSONObject payload = params[0];
        String beaconRequestApi = null;
        String requestToken = null;
        try {
            beaconRequestApi = (String) params[1].get("beaconRequestApi");
            requestToken = (String) params[1].get("requestToken");
        } catch (JSONException e) {
            e.printStackTrace();
        }
        Log.d("BeaconsAndroidModule", "BeaconRequest beaconRequestApi " + beaconRequestApi + " - requestToken " + requestToken);
        if(stringNotEmpty(beaconRequestApi) && stringNotEmpty(requestToken)) {
            try {
                URL url = new URL(beaconRequestApi);
                con = (HttpURLConnection) url.openConnection();
                con.setRequestMethod("POST");
                con.setRequestProperty("Content-Type", "application/json");
                con.setRequestProperty("Authorization", requestToken);
                con.setDoOutput(true);
                con.connect();
                DataOutputStream wr = new DataOutputStream(con.getOutputStream());
                wr.writeBytes(payload != null ? payload.toString() : "");
                wr.flush();
                wr.close();
                int HttpResult = con.getResponseCode();
                Log.d("BeaconsAndroidModule", "BeaconRequest Response Code " + HttpResult);
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
