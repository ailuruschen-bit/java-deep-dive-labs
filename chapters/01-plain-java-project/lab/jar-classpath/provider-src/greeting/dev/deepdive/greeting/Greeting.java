package dev.deepdive.greeting;

public final class Greeting {
    private Greeting() {
    }

    public static String forName(String name) {
        return "Hello, " + name;
    }
}
