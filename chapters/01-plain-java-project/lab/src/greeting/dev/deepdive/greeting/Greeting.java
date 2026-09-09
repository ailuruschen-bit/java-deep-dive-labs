package dev.deepdive.greeting;

import dev.deepdive.punctuation.Punctuation;

public final class Greeting {
    private Greeting() {
    }

    public static String forName(String name) {
        return "Hello, " + name + Punctuation.exclamationMark();
    }
}
