def speaker(name,returning=['id'])
  return %{
    query {
      Speaker(name: "#{name}") {
         #{returning.join(' ')}
      }
    }
  }
end

def event(name,returning=['id'])
  return %{
    query {
      Event(name: "#{name}") {
         #{returning.join(' ')}
      }
    }
  }
end

def series(name,returning=['id'])
  return %{
    query {
      Series(name: "#{name}") {
         #{returning.join(' ')}
      }
    }
  }
end