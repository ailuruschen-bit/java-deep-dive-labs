package dev.deepdive.loader;

import java.lang.reflect.Method;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.List;

public final class LoaderDemo {
    private LoaderDemo() {
    }

    public static void main(String[] args) throws ReflectiveOperationException {
        if (args.length < 2) {
            throw new IllegalArgumentException(
                    "Usage: LoaderDemo <main-class> <classpath-root>..."
            );
        }

        String mainClassName = args[0];
        List<Path> classPathRoots = Arrays.stream(args)
                .skip(1)
                .map(Path::of)
                .toList();

        DirectoryClassLoader loader = new DirectoryClassLoader(classPathRoots);
        Class<?> mainClass = loader.loadClass(mainClassName);
        Method mainMethod = mainClass.getMethod("main", String[].class);
        mainMethod.invoke(null, (Object) new String[0]);
    }
}
