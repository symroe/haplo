/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.generate;

import com.oneis.jsinterface.KScriptable;

public class KGeneratedBinaryData extends KScriptable implements JSGeneratedFile {
    String proposedFilename;
    String mimeType;
    byte[] data;

    public KGeneratedBinaryData(String proposedFilename, String mimeType, byte[] data) {
        this.proposedFilename = proposedFilename;
        this.mimeType = mimeType;
        this.data = data;
    }

    public String getClassName() {
        return "$GeneratedBinaryData";
    }

    public String getProposedFilename() {
        return proposedFilename;
    }

    public String getMimeType() {
        return mimeType;
    }

    public boolean haveData() {
        return true;
    }

    public byte[] makeData() {
        return data;
    }
}
