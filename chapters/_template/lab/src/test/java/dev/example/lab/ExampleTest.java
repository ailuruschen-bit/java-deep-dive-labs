package dev.example.lab;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertTrue;

class ExampleTest {
    @Test
    void startsFromAPassingTest() {
        assertTrue(Example.isReady());
    }
}
