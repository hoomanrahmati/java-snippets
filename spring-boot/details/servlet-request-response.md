## HttpServletRequest-HttpServletResponse

[back](../README.md)

[HttpServletResponse Details](./servlet-beyond-1.md)

[Working with Files and Folders](./read-files.md)

In Spring Boot `@RestController`, `HttpServletRequest` and `HttpServletResponse` are **not required** for most use cases, but they provide **low-level access** to the HTTP request/response when you need fine-grained control.

## Common Uses:

### **HttpServletRequest**

```java
@RestController
public class MyController {

    @GetMapping("/example")
    public String example(HttpServletRequest request) {
        // 1. Access request metadata
        String method = request.getMethod();        // GET, POST, etc.
        String uri = request.getRequestURI();       // /example
        String ip = request.getRemoteAddr();        // Client IP

        // 2. Read headers manually
        String authHeader = request.getHeader("Authorization");

        // 3. Get query parameters (?id=123)
        String param = request.getParameter("id");

        // 4. Access attributes (from filters/interceptors)
        Object user = request.getAttribute("currentUser");

        // 5. Read request body as stream (rare, use @RequestBody instead)
        // BufferedReader reader = request.getReader();

        return "OK";
    }
}
```

### **HttpServletResponse**

```java
@RestController
public class MyController {

    @GetMapping("/download")
    public void download(HttpServletResponse response) throws IOException {
        // 1. Set custom response headers
        response.setHeader("X-Custom-Header", "value");
        response.setContentType("application/pdf");
        response.setHeader("Content-Disposition", "attachment; filename=file.pdf");

        // 2. Set HTTP status code
        response.setStatus(HttpServletResponse.SC_CREATED); // 201

        // 3. Write binary data directly
        byte[] data = getFileData();
        response.getOutputStream().write(data);

        // 4. Add cookies
        Cookie cookie = new Cookie("sessionId", "123");
        response.addCookie(cookie);
    }

    @PostMapping("/redirect")
    public void redirect(HttpServletResponse response) throws IOException {
        response.sendRedirect("/new-location");
    }
}
```

## **When to use them vs. Spring abstractions:**

| **Scenario**                         | **Better Approach**                   |
| ------------------------------------ | ------------------------------------- |
| Read request body                    | `@RequestBody`                        |
| Get query parameters                 | `@RequestParam`                       |
| Get path variables                   | `@PathVariable`                       |
| Get headers                          | `@RequestHeader`                      |
| Set response status                  | `@ResponseStatus` or `ResponseEntity` |
| Set response headers                 | `ResponseEntity` or `@ResponseHeader` |
| Download files                       | `HttpServletResponse` ✅              |
| Set cookies                          | `HttpServletResponse` ✅              |
| Access client IP                     | `HttpServletRequest` ✅               |
| Access filter/interceptor attributes | `HttpServletRequest` ✅               |
| Send raw binary data                 | `HttpServletResponse` ✅              |

## **Best Practice Example with ResponseEntity:**

```java
// Preferred for most cases
@GetMapping("/{id}")
public ResponseEntity<User> getUser(@PathVariable Long id) {
    User user = userService.findById(id);
    return ResponseEntity
        .ok()
        .header("X-Custom", "value")
        .body(user);
}

// Use HttpServletRequest/Response only when needed
@GetMapping("/download")
public void downloadFile(HttpServletResponse response) throws IOException {
    // When streaming large files or needing low-level control
    response.setContentType("application/octet-stream");
    response.setHeader("Content-Disposition", "attachment; filename=data.bin");
    // Stream directly to response output stream
    fileService.streamTo(response.getOutputStream());
}
```

## **Key Takeaway:**

- **Don't use them by default** - Spring's annotations (`@RequestParam`, `@RequestBody`, `ResponseEntity`) are cleaner and testable.
- **Use `HttpServletRequest`** for accessing raw request metadata, client IP, or attributes set in filters.
- **Use `HttpServletResponse`** for binary streaming, cookie manipulation, or when you need to write directly to the output stream before returning.

---

Great question! Beyond the basics, here are **advanced and lesser-known capabilities** of `HttpServletRequest` and `HttpServletResponse` in Spring Boot:

## **HttpServletRequest - Advanced Capabilities**

### **1. Session Management**

```java
@RestController
public class SessionController {

    @PostMapping("/login")
    public String login(HttpServletRequest request) {
        // Get or create session
        HttpSession session = request.getSession();
        session.setAttribute("userId", 123);
        session.setMaxInactiveInterval(3600); // 1 hour

        // Change session ID (security - prevent session fixation)
        request.changeSessionId();

        // Get session creation time
        long creationTime = session.getCreationTime();

        return "Logged in";
    }

    @GetMapping("/session-info")
    public Map<String, Object> sessionInfo(HttpServletRequest request) {
        HttpSession session = request.getSession(false); // Don't create if doesn't exist
        if (session != null) {
            return Map.of(
                "id", session.getId(),
                "creationTime", session.getCreationTime(),
                "lastAccessTime", session.getLastAccessedTime(),
                "isNew", session.isNew()
            );
        }
        return Map.of("error", "No session");
    }
}
```

### **2. Content Negotiation & Locale**

```java
@RestController
public class LocaleController {

    @GetMapping("/info")
    public String getLocaleInfo(HttpServletRequest request) {
        // Get accepted locales from Accept-Language header
        Enumeration<Locale> locales = request.getLocales();

        // Get preferred locale
        Locale preferred = request.getLocale();

        // Get character encoding
        String encoding = request.getCharacterEncoding();

        // Get content type of request
        String contentType = request.getContentType();

        return String.format("Locale: %s, Encoding: %s", preferred, encoding);
    }
}
```

### **3. SSL/TLS Information**

```java
@RestController
public class SecurityController {

    @GetMapping("/security-info")
    public Map<String, String> getSecurityInfo(HttpServletRequest request) {
        Map<String, String> info = new HashMap<>();

        // Check if request is over HTTPS
        info.put("isSecure", String.valueOf(request.isSecure()));

        // Get SSL attributes (if available)
        info.put("cipherSuite", (String) request.getAttribute("javax.servlet.request.cipher_suite"));
        info.put("keySize", String.valueOf(request.getAttribute("javax.servlet.request.key_size")));

        // Get client certificate (if mutual TLS)
        X509Certificate[] certs = (X509Certificate[]) request.getAttribute("javax.servlet.request.X509Certificate");
        if (certs != null && certs.length > 0) {
            info.put("clientCert", certs[0].getSubjectDN().getName());
        }

        return info;
    }
}
```

### **4. Async Processing Support**

```java
@RestController
public class AsyncController {

    @GetMapping("/async-data")
    public CompletableFuture<String> asyncData(HttpServletRequest request) {
        // Start async mode
        AsyncContext asyncContext = request.startAsync();

        // Set timeout
        asyncContext.setTimeout(5000);

        // Add listener for async events
        asyncContext.addListener(new AsyncListener() {
            @Override
            public void onComplete(AsyncEvent event) {
                System.out.println("Async complete");
            }

            @Override
            public void onTimeout(AsyncEvent event) {
                System.out.println("Async timeout");
                asyncContext.getResponse().setStatus(408);
                asyncContext.complete();
            }

            @Override
            public void onError(AsyncEvent event) {}

            @Override
            public void onStartAsync(AsyncEvent event) {}
        });

        // Process asynchronously
        return CompletableFuture.supplyAsync(() -> {
            try {
                Thread.sleep(1000);
                return "Async result";
            } finally {
                asyncContext.complete();
            }
        });
    }
}
```

### **5. Request Body Inspection Without Consuming**

```java
@RestController
public class DebugController {

    @PostMapping("/debug")
    public String debugRequest(HttpServletRequest request) throws IOException {
        // Peek at request body without consuming it (useful for logging)
        ContentCachingRequestWrapper wrapper = new ContentCachingRequestWrapper(request);

        // Read body (wrapped)
        String body = new String(wrapper.getContentAsByteArray(), wrapper.getCharacterEncoding());

        // Original request still has body for further processing
        return "Body: " + body;
    }

    // Helper method to get all headers
    @GetMapping("/headers")
    public Map<String, String> getAllHeaders(HttpServletRequest request) {
        Map<String, String> headers = new HashMap<>();
        Enumeration<String> headerNames = request.getHeaderNames();
        while (headerNames.hasMoreElements()) {
            String headerName = headerNames.nextElement();
            headers.put(headerName, request.getHeader(headerName));
        }
        return headers;
    }
}
```

---

## **HttpServletResponse - Advanced Capabilities**

### **1. Chunked Transfer Encoding (Streaming Large Responses)**

```java
@RestController
public class StreamingController {

    @GetMapping("/stream-large-data")
    public void streamLargeData(HttpServletResponse response) throws IOException {
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        // Enable chunked encoding
        response.setBufferSize(8192); // 8KB chunks

        PrintWriter writer = response.getWriter();
        writer.write("[");

        for (int i = 0; i < 10000; i++) {
            writer.write(String.format("{\"id\":%d}", i));
            if (i < 9999) writer.write(",");
            writer.flush(); // Send chunk
        }

        writer.write("]");
        writer.flush();
    }

    // Server-Sent Events (SSE)
    @GetMapping("/sse-events")
    public void sseEvents(HttpServletResponse response) throws IOException {
        response.setContentType("text/event-stream");
        response.setCharacterEncoding("UTF-8");
        response.setHeader("Cache-Control", "no-cache");

        PrintWriter writer = response.getWriter();

        for (int i = 0; i < 10; i++) {
            writer.write("data: Message " + i + "\n\n");
            writer.flush();
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                break;
            }
        }
    }
}
```

### **2. Response Buffer Management**

```java
@RestController
public class BufferController {

    @GetMapping("/buffered-response")
    public void bufferedResponse(HttpServletResponse response) throws IOException {
        // Check buffer size
        int bufferSize = response.getBufferSize();

        // Set custom buffer size
        response.setBufferSize(16384); // 16KB

        PrintWriter writer = response.getWriter();
        writer.write("Some content");

        // Check if response committed
        if (!response.isCommitted()) {
            // Reset buffer (clear content but keep headers)
            response.resetBuffer();
            writer.write("New content after reset");
        }

        // Force flush
        response.flushBuffer();
    }
}
```

### **3. Custom MIME Types and File Upload**

```java
@RestController
public class FileController {

    @GetMapping("/download-multiple")
    public void downloadMultipleFiles(HttpServletResponse response) throws IOException {
        // Zip multiple files on the fly
        response.setContentType("application/zip");
        response.setHeader("Content-Disposition", "attachment; filename=files.zip");

        ZipOutputStream zos = new ZipOutputStream(response.getOutputStream());

        // Add first file
        zos.putNextEntry(new ZipEntry("file1.txt"));
        zos.write("Content of file 1".getBytes());
        zos.closeEntry();

        // Add second file
        zos.putNextEntry(new ZipEntry("file2.txt"));
        zos.write("Content of file 2".getBytes());
        zos.closeEntry();

        zos.finish();
        zos.flush();
    }

    // Dynamic content type
    @GetMapping("/dynamic-content/{type}")
    public void dynamicContent(@PathVariable String type, HttpServletResponse response) throws IOException {
        switch(type) {
            case "json":
                response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                response.getWriter().write("{\"type\":\"json\"}");
                break;
            case "xml":
                response.setContentType(MediaType.APPLICATION_XML_VALUE);
                response.getWriter().write("<root><type>xml</type></root>");
                break;
            case "pdf":
                response.setContentType(MediaType.APPLICATION_PDF_VALUE);
                // Generate PDF and write to output stream
                break;
        }
    }
}
```

### **4. Partial Content (Range Requests)**

```java
@RestController
public class VideoController {

    @GetMapping("/video")
    public void streamVideo(HttpServletRequest request, HttpServletResponse response) throws IOException {
        File videoFile = new File("video.mp4");
        long fileLength = videoFile.length();
        long rangeStart = 0;
        long rangeEnd = fileLength - 1;

        // Parse Range header
        String rangeHeader = request.getHeader("Range");
        if (rangeHeader != null && rangeHeader.startsWith("bytes=")) {
            String[] ranges = rangeHeader.substring(6).split("-");
            rangeStart = Long.parseLong(ranges[0]);
            if (ranges.length > 1 && !ranges[1].isEmpty()) {
                rangeEnd = Long.parseLong(ranges[1]);
            }

            response.setStatus(HttpServletResponse.SC_PARTIAL_CONTENT);
            response.setHeader("Content-Range",
                String.format("bytes %d-%d/%d", rangeStart, rangeEnd, fileLength));
        }

        long contentLength = rangeEnd - rangeStart + 1;
        response.setContentType("video/mp4");
        response.setHeader("Accept-Ranges", "bytes");
        response.setContentLengthLong(contentLength);

        // Stream only requested range
        try (RandomAccessFile raf = new RandomAccessFile(videoFile, "r");
             OutputStream out = response.getOutputStream()) {
            raf.seek(rangeStart);
            byte[] buffer = new byte[8192];
            long bytesRemaining = contentLength;
            int bytesRead;

            while (bytesRemaining > 0 && (bytesRead = raf.read(buffer, 0,
                   (int) Math.min(buffer.length, bytesRemaining))) != -1) {
                out.write(buffer, 0, bytesRead);
                bytesRemaining -= bytesRead;
            }
            out.flush();
        }
    }
}
```

### **5. ETag and Cache Control**

```java
@RestController
public class CacheController {

    @GetMapping("/cached-data")
    public void getCachedData(HttpServletRequest request, HttpServletResponse response) {
        String etag = "\"v1-" + Integer.toHexString(data.hashCode()) + "\"";
        String ifNoneMatch = request.getHeader("If-None-Match");

        if (etag.equals(ifNoneMatch)) {
            response.setStatus(HttpServletResponse.SC_NOT_MODIFIED);
            return;
        }

        // Set cache headers
        response.setHeader("ETag", etag);
        response.setDateHeader("Last-Modified", lastModified);
        response.setHeader("Cache-Control", "max-age=3600, must-revalidate");

        // Return full response
        response.setContentType("application/json");
        // ... write data
    }

    // Prevent caching
    @GetMapping("/no-cache")
    public void noCache(HttpServletResponse response) {
        response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
        response.setHeader("Pragma", "no-cache");
        response.setDateHeader("Expires", 0);
    }
}
```

### **6. Custom Error Handling**

```java
@RestController
public class ErrorController {

    @GetMapping("/custom-error")
    public void customError(HttpServletResponse response) throws IOException {
        // Send error with custom message
        response.sendError(429, "Too Many Requests - Rate limit exceeded");

        // Or build custom error page
        response.setStatus(418);
        response.setContentType("text/html");
        response.getWriter().write("<h1>I'm a teapot</h1>");
    }

    // Reset response for retry
    @GetMapping("/reset-example")
    public void resetResponse(HttpServletResponse response) throws IOException {
        response.setHeader("X-Test", "value");
        response.getWriter().write("Initial content");

        if (needsRetry()) {
            response.reset(); // Clear headers and body
            response.setStatus(500);
            response.getWriter().write("Retry later");
        }
    }
}
```

## **Pro Tips & Gotchas:**

1. **Response Committed**: Once you call `getWriter()` or `getOutputStream()`, the response is committed and you can't change headers
2. **Request Body**: Can only be read once unless wrapped with `ContentCachingRequestWrapper`
3. **Performance**: For large responses, use chunked encoding or streaming instead of building everything in memory
4. **Thread Safety**: `HttpServletRequest/Response` are not thread-safe per request
5. **Testing**: Use `MockHttpServletRequest/Response` for unit tests

These advanced features are powerful but should be used **only when Spring's higher-level abstractions don't suffice**!

---

### Upload Large File (JS)

```javascript
// For very large files - streams the file chunk by chunk
async function uploadLargeFile(file) {
  // Create a stream that reads the file in chunks
  const stream = file.stream(); // Creates a ReadableStream

  const response = await fetch("http://localhost:8080/upload", {
    method: "POST",
    body: stream, // Stream directly - not loaded entirely into memory!
    headers: {
      "Content-Type": "application/octet-stream", // Or appropriate type
      "Content-Length": file.size.toString(), // Must know size beforehand
    },
  });

  return response;
}
```
