/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.appserver;

import java.io.*;
import java.util.Map;
import java.util.HashMap;
import java.util.zip.GZIPOutputStream;
import java.util.Vector;
import java.util.List;

import javax.servlet.http.HttpServletResponse;
import org.eclipse.jetty.server.InclusiveByteRange;

/**
 * Application server response base class. Objects of this type are generated by
 * the request handling process.
 *
 * Has a default implementation of gzipping responses, which will be appropraite
 * for most dervived classes.
 */
public class Response {
    public static final long CONTENT_LENGTH_UNCERTAIN = -1;
    public static final long NOT_GZIPABLE = -2;

    // How big should a response be before it's considered gzipable?
    public static final long MINIMUM_GZIP_SIZE = 128;
    // How big can a response be before it's compressed as a stream?
    public static final long MAXIMUM_ONE_SHOT_COMPRESION_SIZE = 1024 * 1024;

    private Vector<String[]> headers;
    private byte[] compressed;

    /**
     * Constructor
     */
    public Response() {
        headers = new Vector<String[]>();
        this.compressed = null;
    }

    /**
     * Add a header for returning with this response.
     */
    public void addHeader(String name, String value) {
        headers.add(new String[]{name, value});
    }

    /**
     * Get the first value for a header, or null if that header can't be found
     */
    public String getFirstHeader(String name) {
        for(String[] h : headers) {
            if(name.equalsIgnoreCase(h[0])) {
                return h[1];
            }
        }
        return null;
    }

    /**
     * Returns true if this response has been suspended. Continuation support
     * uses this to stop all processing, so the response can be resumed later.
     */
    public boolean isSuspended() {
        return false;
    }

    /**
     * Returns the HTTP response code
     */
    public int getResponseCode() {
        return 200;
    }

    /**
     * Returns the length of the unencoded data, must match the size of data
     * written by writeToOutputStream()
     *
     * May return CONTENT_LENGTH_UNCERTAIN.
     *
     * @return size of unencoded data
     */
    public long getContentLength() {
        return 0;
    }

    /**
     * Whether this response should be treated as a static response which will
     * never change.
     */
    public boolean getBehavesAsStaticFile() {
        return false;
    }

    /**
     * Whether this response supports ranges. If true, getContentLength() must
     * NOT return CONTENT_LENGTH_UNCERTAIN.
     */
    public boolean supportsRanges() {
        return false;
    }

    /**
     * Returns the length of the data, gzipped, must match the size of data
     * written by writeToOutputStreamGzipped()
     *
     * May return CONTENT_LENGTH_UNCERTAIN, or NOT_GZIPABLE if the response
     * should not be gzipped.
     *
     * @return size of gzipped data
     */
    public long getContentLengthGzipped() {
        long uncompressedLength = this.getContentLength();

        // If the size isn't known, return a similar "don't know"
        if(uncompressedLength == CONTENT_LENGTH_UNCERTAIN) {
            return CONTENT_LENGTH_UNCERTAIN;
        }

        // If the response isn't very big, don't compress
        if(uncompressedLength < MINIMUM_GZIP_SIZE) {
            return NOT_GZIPABLE;
        }

        // If the response is big, stream it instead of compressing it now
        if(uncompressedLength > MAXIMUM_ONE_SHOT_COMPRESION_SIZE) {
            return CONTENT_LENGTH_UNCERTAIN;
        }

        // Otherwise, gzip it now.
        int bufSize = 8 * 1024;
        if(bufSize < (uncompressedLength / 2)) {
            bufSize = (int)(uncompressedLength / 2);
        }
        try {
            ByteArrayOutputStream c = new ByteArrayOutputStream(bufSize);
            GZIPOutputStream compressor = new GZIPOutputStream(c, bufSize);
            this.writeToOutputStream(compressor);
            compressor.close();
            compressed = c.toByteArray();
        } catch(IOException e) {
            // Ooops. Give up.
            return NOT_GZIPABLE;
        }

        // Check there is some point to compression (taking into account extra headers)
        if((compressed.length + 20) > uncompressedLength) {
            compressed = null;
            return NOT_GZIPABLE;
        }

        return compressed.length;
    }

    /**
     * Write the content to the a servlet response
     */
    public final void writeToServletResponse(HttpServletResponse servletResponse, boolean gzipped, List ranges) throws IOException {
        OutputStream out = servletResponse.getOutputStream();

        // Send ranges?
        if(ranges != null) {
            if(!supportsRanges()) {
                throw new RuntimeException("Attempting to send HTTP response to request with ranges when not supported by Response object.");
            }
            if(gzipped) {
                throw new RuntimeException("HTTP response set up to use gzip, but sending ranges, which isn't supported by Response object.");
            }
            if(ranges.size() != 1) {
                throw new RuntimeException("Sending more than one range in a HTTP response isn't supported yet.");
            }

            long contentLength = getContentLength();
            if(contentLength == CONTENT_LENGTH_UNCERTAIN) {
                throw new RuntimeException("HTTP Response is not allowed to have an uncertain content length when handling ranges.");
            }

            InclusiveByteRange singleSatisfiableRange = (InclusiveByteRange)ranges.get(0);
            long singleLength = singleSatisfiableRange.getSize(contentLength);
            this.writeRangeToOutputStream(out,
                    singleSatisfiableRange.getFirst(contentLength),
                    singleSatisfiableRange.getSize(contentLength));
            return;
        }

        if(gzipped) {
            this.writeToOutputStreamGzipped(out);
        } else {
            this.writeToOutputStream(out);
        }
    }

    /**
     * Writes the response data to an output stream.
     */
    public void writeToOutputStream(OutputStream stream) throws IOException {
    }

    /**
     * Writes a range of the response data to an output stream.
     */
    public void writeRangeToOutputStream(OutputStream stream, long offset, long length) throws IOException {
        throw new RuntimeException("writeRangeToOutputStream() is not supported");
    }

    /**
     * Writes the response data to an output stream with gzipping.
     */
    public void writeToOutputStreamGzipped(OutputStream stream) throws IOException {
        if(compressed != null) {
            stream.write(compressed);
        } else {
            GZIPOutputStream compressor = new GZIPOutputStream(stream, 8 * 1024);
            this.writeToOutputStream(compressor);
            compressor.finish();    // don't close the underlying stream
        }
    }

    /**
     * Return an exact length byte[] buffer of the uncompressed content, or null
     * for not possible.
     */
    public byte[] getRawBuffer() throws IOException {
        return null;
    }

    /**
     * Return an exact length byte[] buffer of the gzipped content, or null for
     * not possible.
     */
    public byte[] getRawGzippedBuffer() throws IOException {
        return compressed;
    }

    /**
     * Merges the headers for this object into the headers for the response.
     */
    public void applyHeadersTo(HttpServletResponse servletResponse) {
        for(String[] h : headers) {
            servletResponse.addHeader(h[0], h[1]);
        }
    }
}
