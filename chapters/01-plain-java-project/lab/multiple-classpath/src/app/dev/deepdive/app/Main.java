package dev.deepdive.app;

import dev.deepdive.greeting.Greeting;

public class Main {
    public static void main(String[] args) {
        System.out.println(Greeting.forName("classpath"));
    }
}
