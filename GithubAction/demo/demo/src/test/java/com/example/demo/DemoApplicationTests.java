package com.example.demo;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
class DemoApplicationTests {

	@Test
	void contextLoads() {
		Hello hello = new Hello();
		hello.setId(1);
		hello.setName("one");

		assertEquals("one", hello.getName());
	}

}
