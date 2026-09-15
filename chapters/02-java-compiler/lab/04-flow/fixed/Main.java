public class Main {
    public static void main(String[] args) {
        String message;
        if (args.length > 0) {
            message = args[0];
        } else {
            message = "Hello, compiler!";
        }
        System.out.println(message);
    }
}
