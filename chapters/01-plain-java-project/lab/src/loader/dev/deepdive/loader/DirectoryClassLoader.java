package dev.deepdive.loader;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

public final class DirectoryClassLoader extends ClassLoader {
    private final List<Path> classPathRoots;

    public DirectoryClassLoader(List<Path> classPathRoots) {
        classPathRoots.forEach(root -> {
            if (!Files.isDirectory(root)) {
                throw new IllegalArgumentException("Not a directory: " + root);
            }
        });
        this.classPathRoots = List.copyOf(classPathRoots);
    }

    @Override
    protected Class<?> findClass(String binaryName) throws ClassNotFoundException {
        String relativePath = binaryName.replace('.', '/') + ".class";

        for (Path root : classPathRoots) {
            Path classFile = root.resolve(relativePath);
            if (Files.isRegularFile(classFile)) {
                try {
                    byte[] classBytes = Files.readAllBytes(classFile);
                    return defineClass(binaryName, classBytes, 0, classBytes.length);
                } catch (IOException exception) {
                    throw new ClassNotFoundException(binaryName, exception);
                }
            }
        }

        throw new ClassNotFoundException(binaryName);
    }
}
