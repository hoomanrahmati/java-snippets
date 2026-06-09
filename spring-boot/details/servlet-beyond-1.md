## HttpServletResponse (**Core Response Methods**)

[back](./servlet-request-response.md)

- **`setStatus(int sc)`** / **`setStatus(int sc, String sm)`** - Set HTTP status code
- **`sendError(int sc)`** / **`sendError(int sc, String msg)`** - Send error responses
- **`sendRedirect(String location)`** - Redirect client to another URL
- **`encodeRedirectURL(String url)`** / **`encodeURL(String url)`** - Encode URLs with session ID if needed

## **Header Management**

- **`setHeader(String name, String value)`** - Set response headers
- **`addHeader(String name, String value)`** - Add header (allows multiple values)
- **`setIntHeader(String name, int value)`** - Set integer header
- **`addIntHeader(String name, int value)`** - Add integer header
- **`setDateHeader(String name, long date)`** - Set date header
- **`addDateHeader(String name, long date)`** - Add date header
- **`containsHeader(String name)`** - Check if header exists
- **`getHeaderNames()`** - Get all header names
- **`getHeaders(String name)`** - Get header values

## **Content Management**

- **`setContentType(String type)`** - Set MIME type (e.g., "application/json")
- **`setContentLength(int len)`** - Set content length
- **`setContentLengthLong(long len)`** - Set content length (long version)
- **`setCharacterEncoding(String charset)`** - Set character encoding
- **`getCharacterEncoding()`** - Get current encoding

## **Cookie Management**

- **`addCookie(Cookie cookie)`** - Add cookie to response

## **Buffer Control**

- **`setBufferSize(int size)`** - Set response buffer size
- **`getBufferSize()`** - Get current buffer size
- **`flushBuffer()`** - Force buffer contents to client
- **`reset()`** - Clear buffer and headers (if not committed)
- **`resetBuffer()`** - Clear buffer only
- **`isCommitted()`** - Check if response already sent

## **Locale & Other**

- **`setLocale(Locale loc)`** - Set response locale
- **`getLocale()`** - Get current locale
- **`getOutputStream()`** - Get binary output stream (alternative to getWriter)

## **Example Usage**

```java
@GetMapping("/example")
public void example(HttpServletResponse response) throws IOException {
    // Status and headers
    response.setStatus(HttpStatus.OK.value());
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");
    response.setHeader("Cache-Control", "no-cache");

    // Cookies
    Cookie cookie = new Cookie("user", "john");
    response.addCookie(cookie);

    // Redirect (alternative to returning view)
    // response.sendRedirect("/login");

    // Write response
    PrintWriter writer = response.getWriter();
    writer.write("{\"message\": \"Hello\"}");

    // Or use OutputStream for binary
    // ServletOutputStream os = response.getOutputStream();
    // os.write(bytes);
}
```

**Note**: You cannot use both `getWriter()` and `getOutputStream()` on the same response - choose one based on whether you're sending text or binary data.

---

### Common Content Types for Images:

```java
// For JPG/JPEG
response.setContentType("image/jpeg");

// For PNG
response.setContentType("image/png");

// For GIF
response.setContentType("image/gif");

// For WEBP
response.setContentType("image/webp");

// For SVG (this one is text, so encoding matters)
response.setContentType("image/svg+xml");
response.setCharacterEncoding("UTF-8");
```

---

## **Common Content Types for `getWriter()`**

When using `getWriter()` (text-based output), you typically set `Content-Type` and sometimes additional headers. Here are the main types:

### **1. Server-Sent Events (SSE)**

```java
response.setContentType("text/event-stream");
response.setCharacterEncoding("UTF-8");
response.setHeader("Cache-Control", "no-cache");
response.setHeader("Connection", "keep-alive");

PrintWriter writer = response.getWriter();
writer.write("data: Hello World\n\n");
writer.flush();
```

### **2. JSON APIs**

```java
response.setContentType("application/json");
response.setCharacterEncoding("UTF-8");

PrintWriter writer = response.getWriter();
writer.write("{\"name\":\"John\",\"age\":30}");
```

### **3. XML Responses**

```java
response.setContentType("application/xml");
// or "text/xml" for older systems
response.setCharacterEncoding("UTF-8");

PrintWriter writer = response.getWriter();
writer.write("<?xml version=\"1.0\"?><user><name>John</name></user>");
```

### **4. HTML Pages**

```java
response.setContentType("text/html");
response.setCharacterEncoding("UTF-8");

PrintWriter writer = response.getWriter();
writer.write("<!DOCTYPE html><html><body><h1>Hello</h1></body></html>");
```

### **5. Plain Text**

```java
response.setContentType("text/plain");
response.setCharacterEncoding("UTF-8");

PrintWriter writer = response.getWriter();
writer.write("Simple text output");
```

### **6. JavaScript**

```java
response.setContentType("application/javascript");
// or "text/javascript" (deprecated but still used)

PrintWriter writer = response.getWriter();
writer.write("function hello() { return 'world'; }");
```

### **7. CSS**

```java
response.setContentType("text/css");
response.setCharacterEncoding("UTF-8");

PrintWriter writer = response.getWriter();
writer.write("body { background-color: #f0f0f0; }");
```

### **8. CSV Data**

```java
response.setContentType("text/csv");
response.setHeader("Content-Disposition", "attachment; filename=data.csv");

PrintWriter writer = response.getWriter();
writer.write("name,age,city\n");
writer.write("John,30,NYC\n");
writer.write("Jane,25,LA\n");
```

### **9. Form URL Encoded**

```java
response.setContentType("application/x-www-form-urlencoded");

PrintWriter writer = response.getWriter();
writer.write("name=John&age=30&city=NYC");
```

### **10. YAML**

```java
response.setContentType("application/yaml");
// or "text/yaml"

PrintWriter writer = response.getWriter();
writer.write("name: John\nage: 30\ncity: NYC");
```

### **11. EventSource / NDJSON (Newline Delimited JSON)**

```java
response.setContentType("application/x-ndjson");
response.setCharacterEncoding("UTF-8");

PrintWriter writer = response.getWriter();
writer.write("{\"id\":1,\"data\":\"first\"}\n");
writer.write("{\"id\":2,\"data\":\"second\"}\n");
```

### **12. GraphQL**

```java
response.setContentType("application/graphql");
response.setCharacterEncoding("UTF-8");

PrintWriter writer = response.getWriter();
writer.write("{\"query\":\"{user{name}}\"}");
```

### **13. JPEG Files**

```java
response.setContentType("image/jpeg");
```

## **Additional Headers You Might Use**

```java
// File download
response.setHeader("Content-Disposition", "attachment; filename=\"file.txt\"");

// CORS
response.setHeader("Access-Control-Allow-Origin", "*");
response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT");

// Caching control
response.setHeader("Cache-Control", "max-age=3600, public");
response.setHeader("Pragma", "cache");

// Compression (usually handled by server)
response.setHeader("Content-Encoding", "gzip");

// Security
response.setHeader("X-Content-Type-Options", "nosniff");
response.setHeader("X-Frame-Options", "DENY");
response.setHeader("Content-Security-Policy", "default-src 'self'");

// Streaming/Real-time
response.setHeader("X-Accel-Buffering", "no"); // Disable nginx buffering
```

## **Complete SSE Example with Heartbeat**

```java
@GetMapping("/stream")
public void streamEvents(HttpServletResponse response) throws IOException {
    response.setContentType("text/event-stream");
    response.setCharacterEncoding("UTF-8");
    response.setHeader("Cache-Control", "no-cache");
    response.setHeader("Connection", "keep-alive");

    PrintWriter writer = response.getWriter();

    // Send initial connection message
    writer.write("event: connected\n");
    writer.write("data: Connection established\n\n");
    writer.flush();

    // Send periodic updates
    for (int i = 0; i < 10; i++) {
        writer.write("event: message\n");
        writer.write("data: Update " + i + "\n\n");
        writer.flush();

        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            break;
        }
    }

    writer.write("event: close\n");
    writer.write("data: Stream ended\n\n");
    writer.flush();
}
```

**Key Points:**

- `getWriter()` is for **text-based** content (characters)
- Use `getOutputStream()` for **binary** data (images, PDFs, zip files)
- Always set Content-Type before getting the writer
- Call `flush()` periodically for streaming responses
- Some content types require additional headers (like SSE)

---

## **Handling Image Responses in Spring Boot**

When returning an image, you **cannot use `getWriter()`** - you must use `getOutputStream()` because images are **binary data**, not text.

### **Basic Image Response**

```java
@GetMapping("/image")
public void getImage(HttpServletResponse response) throws IOException {
    // Set content type based on image format
    response.setContentType("image/jpeg");  // or image/png, image/gif, etc.

    // Read image file
    File file = new File("path/to/image.jpg");
    byte[] imageBytes = Files.readAllBytes(file.toPath());

    // Set content length (good practice)
    response.setContentLength(imageBytes.length);

    // Write binary data
    ServletOutputStream outputStream = response.getOutputStream();
    outputStream.write(imageBytes);
    outputStream.flush();
}
```

### **Common Image Content Types**

```java
response.setContentType("image/jpeg");   // JPEG photos
response.setContentType("image/png");    // PNG (transparency support)
response.setContentType("image/gif");    // GIF (animations)
response.setContentType("image/webp");   // WebP (modern format)
response.setContentType("image/bmp");    // Bitmap
response.setContentType("image/svg+xml"); // SVG (actually XML text!)
```

### **Streaming Large Images Efficiently**

```java
@GetMapping("/large-image")
public void streamLargeImage(HttpServletResponse response) throws IOException {
    response.setContentType("image/jpeg");
    response.setHeader("Content-Disposition", "inline; filename=\"photo.jpg\"");

    try (InputStream inputStream = new FileInputStream("large-photo.jpg");
         ServletOutputStream outputStream = response.getOutputStream()) {

        byte[] buffer = new byte[8192];  // 8KB buffer
        int bytesRead;
        while ((bytesRead = inputStream.read(buffer)) != -1) {
            outputStream.write(buffer, 0, bytesRead);
        }
        outputStream.flush();
    }
}
```

### **Dynamic Image Generation (e.g., Captcha)**

```java
@GetMapping("/captcha")
public void generateCaptcha(HttpServletResponse response) throws IOException {
    response.setContentType("image/png");
    response.setHeader("Cache-Control", "no-store, no-cache");

    // Create buffered image
    BufferedImage image = new BufferedImage(200, 50, BufferedImage.TYPE_INT_RGB);
    Graphics2D g = image.createGraphics();

    // Draw background
    g.setColor(Color.WHITE);
    g.fillRect(0, 0, 200, 50);

    // Draw text
    g.setColor(Color.BLACK);
    g.setFont(new Font("Arial", Font.BOLD, 20));
    String captchaText = generateRandomText();  // Your method
    g.drawString(captchaText, 50, 30);

    // Add noise
    g.setColor(Color.GRAY);
    for (int i = 0; i < 100; i++) {
        g.drawLine(random.nextInt(200), random.nextInt(50),
                   random.nextInt(200), random.nextInt(50));
    }

    g.dispose();

    // Write to response
    ImageIO.write(image, "PNG", response.getOutputStream());
}
```

### **Image Download (Attachment)**

```java
@GetMapping("/download-image")
public void downloadImage(HttpServletResponse response) throws IOException {
    response.setContentType("image/png");
    response.setHeader("Content-Disposition", "attachment; filename=\"screenshot.png\"");
    // Forces download instead of display

    byte[] imageBytes = getImageBytes();  // Your image source
    response.setContentLength(imageBytes.length);

    ServletOutputStream outputStream = response.getOutputStream();
    outputStream.write(imageBytes);
    outputStream.flush();
}
```

### **Thumbnail Generation**

```java
@GetMapping("/thumbnail/{id}")
public void getThumbnail(@PathVariable Long id, HttpServletResponse response) throws IOException {
    response.setContentType("image/jpeg");

    BufferedImage original = ImageIO.read(new File("original.jpg"));

    // Resize to thumbnail
    int thumbWidth = 150;
    int thumbHeight = 150;
    Image thumbnail = original.getScaledInstance(thumbWidth, thumbHeight, Image.SCALE_SMOOTH);

    BufferedImage bufferedThumb = new BufferedImage(thumbWidth, thumbHeight, BufferedImage.TYPE_INT_RGB);
    Graphics2D g = bufferedThumb.createGraphics();
    g.drawImage(thumbnail, 0, 0, null);
    g.dispose();

    ImageIO.write(bufferedThumb, "jpg", response.getOutputStream());
}
```

### **Image from Resource (Classpath)**

```java
@GetMapping("/logo")
public void getLogo(HttpServletResponse response) throws IOException {
    response.setContentType("image/png");

    Resource resource = new ClassPathResource("static/images/logo.png");

    try (InputStream inputStream = resource.getInputStream();
         ServletOutputStream outputStream = response.getOutputStream()) {

        IOUtils.copy(inputStream, outputStream);  // Apache Commons IO
        outputStream.flush();
    }
}
```

### **Progressive JPEG Streaming**

```java
@GetMapping("/progressive-image")
public void progressiveImage(HttpServletResponse response) throws IOException {
    response.setContentType("image/jpeg");
    response.setHeader("Cache-Control", "no-cache");

    // Write headers first
    response.setBufferSize(8192);
    ServletOutputStream out = response.getOutputStream();

    // Simulate progressive loading
    for (int pass = 1; pass <= 4; pass++) {
        byte[] partialData = generateProgressivePass(pass);  // Your logic
        out.write(partialData);
        out.flush();
        Thread.sleep(100);  // Simulate loading delay
    }
}
```

### **Error Handling for Missing Images**

```java
@GetMapping("/safety-image")
public void safeImage(HttpServletResponse response) throws IOException {
    File imageFile = new File("images/photo.jpg");

    if (!imageFile.exists()) {
        response.setStatus(HttpStatus.NOT_FOUND.value());
        response.setContentType("text/plain");
        PrintWriter writer = response.getWriter();
        writer.write("Image not found");
        return;
    }

    response.setContentType(Files.probeContentType(imageFile.toPath()));

    try (InputStream in = new FileInputStream(imageFile);
         ServletOutputStream out = response.getOutputStream()) {
        IOUtils.copy(in, out);
    }
}
```

### **Using Spring's Resource Return (Recommended)**

```java
@GetMapping("/image-spring")
public ResponseEntity<Resource> getImageSpring() {
    Resource imageResource = new FileSystemResource("path/to/image.jpg");

    return ResponseEntity.ok()
        .contentType(MediaType.IMAGE_JPEG)
        .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
        .body(imageResource);
}

// Or simpler with Resource return type
@GetMapping("/image-simple", produces = MediaType.IMAGE_JPEG_VALUE)
public @ResponseBody Resource getImageSimple() {
    return new FileSystemResource("path/to/image.jpg");
}
```

### **Key Differences from `getWriter()`**

| `getWriter()`              | `getOutputStream()`           |
| -------------------------- | ----------------------------- |
| For text data              | For binary data               |
| Returns `PrintWriter`      | Returns `ServletOutputStream` |
| Character encoding matters | Raw bytes                     |
| Can't write images         | Required for images           |
| Examples: JSON, HTML, CSV  | Examples: Images, PDFs, ZIPs  |

**Important:** Never use both `getWriter()` and `getOutputStream()` in the same response - choose one based on your data type!
