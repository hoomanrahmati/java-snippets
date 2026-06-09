## Files and Folders:

[back](./servlet-request-response.md)

- ClassPathResource & StreamUtils (use in production JAR for resources)

```java
// File should be in: src/main/resources/files/1234.jpg
@GetMapping("/pic")
public byte[] pic(HttpServletRequest request, HttpServletResponse response) throws IOException {
  ClassPathResource resource = new ClassPathResource("files/123.jpg");
  response.setContentType("image/jpeg");
  // response.setContentLength((int) resource.getFile().length());
  response.setContentLength((int) resource.contentLength());
  return StreamUtils.copyToByteArray(resource.getInputStream());
  // return Files.readAllBytes(resource.getFile().toPath());
}
```

- Paths - Files (use for absolute path and NOT in production JAR resources)

```java
@GetMapping("/pic")
public byte[] pic(HttpServletRequest request, HttpServletResponse response) throws IOException {
  // /src... will fail
  Path  file = Paths.get("src/main/resources/files/123.jpg");
  response.setContentType("image/jpeg");

  return Files.readAllBytes(file);
  // System.out.println(file.toFile().getAbsolutePath());
}
```

- getAbsolutePath

```java
  Path  file = Paths.get("src/main/resources/files/123.jpg");
  System.out.println(file.toFile().getAbsolutePath());
  // ...\src\main\resources\files\123.jpg
```

```java
  ClassPathResource resource = new ClassPathResource("files/123.jpg");
  System.out.println(resource.getFile().getAbsolutePath());
  // ...\target\classes\files\123.jpg
```

```java
  response.setContentLength((int) resource.contentLength());
  response.setHeader("Content-Length", String.valueOf(resource.contentLength()));
```

### ✅ The RIGHT Way for Large Files - Streaming:

- Result: This bad for large files - they'll cause OutOfMemoryError with files > available heap.

```java
  response.getOutputStream().write(StreamUtils.copyToByteArray(resource.getInputStream()));
  response.getOutputStream().write(Files.readAllBytes(resource.getFile().toPath()));
```

- Best Practice: Stream Without Loading to Memory

```java
  // Good, it doesn't close the output stream, so you can add more data!
  StreamUtils.copy(resource.getInputStream(), response.getOutputStream());
  // close the output stream
  IOUtils.copy(resource.getInputStream(), response.getOutputStream());

  // Use 64KB buffer like manual version
  IOUtils.copyLarge(
      resource.getInputStream(),
      response.getOutputStream(),
      0,     // offset
      -1,    // length (-1 = all)
      new byte[65536]  // 👈 64KB custom buffer
  );

```

```java
  @GetMapping("/pic3")
  public void pic3(HttpServletRequest request, HttpServletResponse response) throws IOException {
      ClassPathResource resource = new ClassPathResource("files/123.jpg");

      response.setContentType("image/jpeg");
      response.setContentLength((int) resource.contentLength());

//        StreamUtils.copy(resource.getInputStream(), response.getOutputStream());
      IOUtils.copy(resource.getInputStream(), response.getOutputStream()); // Apache Commons
  }
```

- using buffer, for very large file:

```java
  @GetMapping("/pic4")
  public void pic4(HttpServletRequest request, HttpServletResponse response) throws IOException {
      ClassPathResource resource = new ClassPathResource("files/123.jpg");

      response.setContentType("image/jpeg");
      response.setHeader("Content-Length", String.valueOf(resource.contentLength()));

      try (InputStream inputStream = resource.getInputStream();
            OutputStream outputStream = response.getOutputStream()) {
          // byte[] buffer = new byte[1024]; // 1K
          byte[] buffer = new byte[65536]; // 64KB is better  for performance

          int len;
          while ((len = inputStream.read(buffer)) != -1) {
              outputStream.write(buffer, 0, len);
              // outputStream.flush(); // don't flush here, for performance issue
          }
          // Flush here! but it don't needed, because when stream close then it flushes
          // outputStream.flush();
      }
  }
```

```java
  @GetMapping("/pic5")
  public void pic5(HttpServletRequest request, HttpServletResponse response) throws IOException {
      Path path = Paths.get("src/main/resources/files/123.jpg");
      File file = path.toFile();

      response.setContentType("image/jpeg");
      response.setHeader("Content-Length", String.valueOf(file.length()));

      try (InputStream inputStream = new FileInputStream(file);
            OutputStream outputStream = response.getOutputStream()) {
          // byte[] buffer = new byte[1024]; // 1K
          byte[] buffer = new byte[65536]; // 64KB is better  for performance
          int len;
          while ((len = inputStream.read(buffer)) != -1) {
              outputStream.write(buffer, 0, len);
              // outputStream.flush(); // don't flush here, for performance issue
          }
          // Flush here! but it don't needed, because when stream close then it flushes
          // outputStream.flush();
      }
  }
```

- change file to FileInputStream

```java
  Path path = Paths.get("src/main/resources/files/123.jpg");
  File file = path.toFile();
  InputStream in = new FileInputStream(file);
```
