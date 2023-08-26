package gotestnvim

import "testing"

func TestSomething(t *testing.T) {
	a := "asdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}
}

func TestSomething2(t *testing.T) {
	a := "sdf"
	if a[0] != 'a' {
		t.Errorf("expected %q, but got %q instead", 'a', a[0])
	}
}
