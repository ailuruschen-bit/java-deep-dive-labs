import java.nio.file.Files;
import java.nio.file.Path;

public class Main {
    public static void main(String[] args) {
        String message = Files.readString(Path.of("message.txt"));
        System.out.println(message);
    }
}
