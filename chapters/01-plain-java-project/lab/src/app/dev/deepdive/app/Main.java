package dev.deepdive.app;

import dev.deepdive.greeting.Greeting;

public final class Main {
    private Main() {
    }

    public static void main(String[] args) {
        System.out.println(Greeting.forName("classpath"));
    }
}
