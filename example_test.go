package gotestnvim

import "testing"

func TestSomethinga(t *testing.T) {
	a := "asdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}

	t.Run("test 1", func(t *testing.T) {

	})
	t.Run("test 2", func(t *testing.T) {

	})
}

func TestAnother(t *testing.T) {
	a := "sdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}
}

func TestYetAnother(t *testing.T) {
	a := "sdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}
}

func TestThis(t *testing.T) {
	a := "sdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}
}

func TestThat(t *testing.T) {
	a := "sdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}
}

func TestMe(t *testing.T) {
	a := "sdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}
}

func TestYou(t *testing.T) {
	a := "sdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}
}

func TestSomething8(t *testing.T) {
	a := "sdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}
}

func TestSomething9(t *testing.T) {
	a := "sdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}
}
