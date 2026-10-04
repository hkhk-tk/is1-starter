package ee.hkhk.laboriseis;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import ee.hkhk.laboriseis.data.Student;
import ee.hkhk.laboriseis.data.StudentRepository;
import ee.hkhk.laboriseis.web.TokenService;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class TokenServiceTest {

    @Test
    void bearerParsesHeader() {
        assertThat(TokenService.bearer("Bearer abc")).isEqualTo("abc");
        assertThat(TokenService.bearer("Basic abc")).isNull();
        assertThat(TokenService.bearer(null)).isNull();
    }

    @Test
    void emptyTeacherTokenNeverMatches() {
        TokenService t = new TokenService(mock(StudentRepository.class), "");
        assertThat(t.isTeacher("")).isFalse();
        assertThat(t.isTeacher(null)).isFalse();
    }

    @Test
    void teacherTokenMatches() {
        TokenService t = new TokenService(mock(StudentRepository.class), "salajane");
        assertThat(t.isTeacher("salajane")).isTrue();
        assertThat(t.isTeacher("vale")).isFalse();
    }

    @Test
    void knownStudentIsRememberedWhenDatabaseFails() {
        StudentRepository repo = mock(StudentRepository.class);
        Student kati = new Student(1, "Kati Kask", "katikask", "IS1-26");
        when(repo.findByToken("abc")).thenReturn(Optional.of(kati));
        TokenService t = new TokenService(repo, "x");
        assertThat(t.student("abc")).contains(kati);
        assertThat(t.student("abc")).contains(kati);
        verify(repo, times(1)).findByToken("abc");
    }
}
