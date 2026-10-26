package android.content;

/**
 * 仅用于编译期占位（compileOnly），不会打进 APK。
 * Delphi 把真实的 android.content.Context 实例传给 CtpBridge。
 */
public class Context {
    public java.io.File getFilesDir() {
        return null;
    }
}
