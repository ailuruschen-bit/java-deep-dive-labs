package dev.example.lab;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class GreetingTest {
    @Test
    void returnsTheBaselineMessage() {
        assertEquals("Java deep-dive lab is ready.", Greeting.message());
    }
}
